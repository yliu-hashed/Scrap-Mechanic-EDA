//
//  Blueprint Check Size.swift
//  Scrap Mechanic EDA
//

import Foundation
import SMEDABlueprint
import SMEDAResult

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

func checkSize(data: borrowing Data, facade: Bool, report: inout PlacementReport, verbose: Bool, lz4Path: String?) {
    let maxEstimate = estimateMaxPacketSize(dataSize: data.count, facade: facade)
    let curSize: Float
    let tolarence: Float
    if let value = lz4BlueprintSize(data: data, lz4Path: lz4Path, verbose: verbose) {
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

#if os(Windows)
private func locateLZ4(verbose: Bool) -> URL? {
    if verbose { print("Warning: Automatically finding LZ4 is unsupported on Windows. Please specify the path to LZ4 manually.") }
    return nil
}
#else
private func locateLZ4(verbose: Bool) -> URL? {
    let fileManager = FileManager.default

    let process = Process()
    process.executableURL = URL(fileURLWithPath: ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/bash")
    process.arguments = ["-l", "-c", "which lz4"]
    process.environment = ProcessInfo.processInfo.environment

    let outputPipe = Pipe()
    process.standardOutput = outputPipe

    let wait = DispatchSemaphore(value: 0)
    process.terminationHandler = { _ in wait.signal() }

    do {
        try process.run()
    } catch {
        print(error.localizedDescription)
        return nil
    }

    let result = wait.wait(timeout: .now() + 2)
    guard result == .success else { return nil }

    let data = outputPipe.fileHandleForReading.availableData
    guard let string = String(data: data, encoding: .utf8) else { return nil }

    let path = string.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !path.isEmpty else { return nil }

    let url = URL(fileURLWithPath: path, isDirectory: false)
    guard fileManager.isReadableFile(atPath: path) else { return nil }
    return url
}
#endif

private func lz4BlueprintSize(data: borrowing Data, lz4Path: String?, verbose: Bool) -> Int? {
    let lz4URL: URL
    if let lz4Path = lz4Path {
        lz4URL = URL(fileURLWithPath: lz4Path)
    } else {
        guard let url = locateLZ4(verbose: verbose) else { return nil }
        lz4URL = url
    }

    if verbose { print("LZ4 is located at \(lz4URL)") }

    let process = Process()
    process.executableURL = lz4URL
    process.arguments = ["-1", "--no-frame-crc", "-BD", "stdin"]

    let inputPipe = Pipe()
    let outputPipe = Pipe()

    process.standardInput = inputPipe
    process.standardOutput = outputPipe

    let outData: Data!
    do {
        try process.run()
        try inputPipe.fileHandleForWriting.write(contentsOf: data)
        try inputPipe.fileHandleForWriting.close()
        outData = try? outputPipe.fileHandleForReading.readToEnd()
    } catch {
        if verbose { print("Unable to perform compression using LZ4: \(error.localizedDescription)") }
        return nil
    }

    return outData.count - 2
}
