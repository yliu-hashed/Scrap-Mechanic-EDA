//
//  Blueprint Check Size.swift
//  Scrap Mechanic EDA
//

import Foundation
import Subprocess
import SMEDABlueprint
import SMEDAResult
#if canImport(System)
@preconcurrency import System
#else
@preconcurrency import SystemPackage
#endif

private let ratioFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.localizesFormat = false
    formatter.numberStyle = .percent
    formatter.maximumFractionDigits = 2
    return formatter
}()

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
        print("Warning: Cannot find lz4, using estimations instead.")
        curSize = estimatePacketSize(dataSize: data.count, facade: facade)
        tolarence = 0.0
    }

    let limit = Float(SMBlueprint.packetSizeLimit)

    let curRatio = curSize / limit
    let maxRatio = maxEstimate / limit

    report.utilization = curRatio
    report.conservativeUtilization = maxRatio

    let curString = ratioFormatter.string(from: NSNumber(value: curRatio))!
    let maxString = ratioFormatter.string(from: NSNumber(value: maxRatio))!

    if verbose {
        print("Blueprint    Utilization: \(curString)")
        print("Conservative Utilization: \(maxString)")
    }

    if curRatio > 1.0 {
        let overSizeRatio = curRatio - 1.0
        let string = ratioFormatter.string(from: NSNumber(value: overSizeRatio))!
        print("Warning: Blueprint is above the limit by \(string). It will likely fail to import.")
    } else if curRatio > (1.0 - tolarence) {
        print("Warning: Blueprint is very large (\(curString)). It will likely fail to import. Please proceed with caution.")
    } else if maxRatio > 1.0 {
        print("Warning: Blueprint is below the limit (\(curString)), but it may fail to import spontaneously later. Conservative utilization is \(maxString). Please proceed with caution.")
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
        arguments: ["-1", "--no-frame-crc", "-BD", "stdin"]
    ) { (execution, input, output, _) in
        _ = try await input.write(data)
        try await input.finish()
        var sum: Int = 0
        for try await chunk in output {
            sum += chunk.count
        }
        try? execution.send(signal: .kill)
        return sum - 2
    }

    return result?.value
}
