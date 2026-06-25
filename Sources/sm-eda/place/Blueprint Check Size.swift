//
//  Blueprint Check Size.swift
//  Scrap Mechanic EDA
//

import Foundation
import Subprocess
import SMEDABlueprint
import SMEDAResult
#if canImport(System)
import System
#else
import SystemPackage
#endif

private func estimatePacketSize(dataSize: Int, facade: Bool) -> Float {
    let value = Float(dataSize)
    return value * (facade ? 0.15 : 0.125)
}

private func estimateMaxPacketSize(dataSize: Int, facade: Bool) -> Float {
    let value = Float(dataSize)
    return value * (facade ? 0.25 : 0.24)
}

func checkSize(data: Data, facade: Bool, report: inout PlacementReport, verbose: Bool, lz4Path: String?) async {
    let maxEstimate = estimateMaxPacketSize(dataSize: data.count, facade: facade)
    let curSize: Float
    let tolarence: Float
    if let value = await lz4BlueprintSize(data: data, lz4Path: lz4Path, verbose: verbose) {
        curSize = Float(value)
        tolarence = 0.05
    } else {
        print(for: .warning, "Cannot find lz4, using estimations instead.")
        curSize = estimatePacketSize(dataSize: data.count, facade: facade)
        tolarence = 0.0
    }

    let limit = Float(SMBlueprint.packetSizeLimit)

    let curRatio = curSize / limit
    let maxRatio = maxEstimate / limit

    report.utilization = curRatio
    report.conservativeUtilization = maxRatio

    let ratioFormat: any FormatStyle<Float, String> = .percent.precision(.fractionLength(2))

    let curString = curRatio.formatted(ratioFormat)
    let maxString = maxRatio.formatted(ratioFormat)

    if verbose {
        print("Blueprint utilization is \(curString).")
        print("Conservative utilization is \(maxString).")
    }

    if curRatio > 1.0 {
        let overSizeRatio = curRatio - 1.0
        let string = overSizeRatio.formatted(ratioFormat)
        print(for: .warning, "Blueprint is above the limit by \(string). It will likely fail to import.")
    } else if curRatio > (1.0 - tolarence) {
        print(for: .warning, "Blueprint is very large (\(curString)). It will likely fail to import. Please proceed with caution.")
    } else if maxRatio > 1.0 && curRatio > 0.8 {
        print(for: .warning, "Blueprint is below the limit (\(curString)), but it may fail to import spontaneously later. Conservative utilization is \(maxString). Please proceed with caution.")
    }
}

private func lz4BlueprintSize(data: Data, lz4Path: String?, verbose: Bool) async -> Int? {
    let executable: Executable
    if let lz4Path = lz4Path {
        executable = .path(.init(lz4Path))
    } else {
        executable = .name("lz4")
    }

    let result = try? await run(
        executable,
        arguments: ["-1", "--no-frame-crc", "-BD", "stdin"],
        input: .inputWriter,
        output: .sequence,
        error: .string(limit: 1024, encoding: UTF8.self)
    ) { execution in
        // write blueprint into the input stream
        let writer = execution.standardInputWriter
        _ = try await writer.write(data)
        try await writer.finish()
        // collect output by summing
        var sum: Int = 0
        for try await chunk in execution.standardOutput {
            sum += chunk.count
        }
        try? execution.send(signal: .kill)
        return sum - 2
    }

    if let error = result?.standardError, !error.isEmpty {
        print(for: .error, "LZ4 has returned error: \(error)")
    }

    return result?.closureOutput
}
