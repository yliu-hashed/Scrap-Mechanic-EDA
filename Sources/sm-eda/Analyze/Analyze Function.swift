//
//  Analyze Function.swift
//  Scrap Mechanic EDA
//

import Foundation
import ArgumentParser
import SMEDANetlist
import SMEDAResult

private let kOutReportFileArgHelp = ArgumentHelp(
    "The path of the json report to write",
    valueName: "out-report"
)

struct AnalyzeArgGroup: ParsableArguments {
    @Flag(name: [.customShort("p"), .customLong("pretty-json")], help: kPrettyPrintArgHelp)
    var prettyPrint: Bool = false

    @Option(name: [.customShort("R"), .customLong("report")],
            help: kOutReportFileArgHelp,
            completion: .file(extensions: ["json"]))
    var reportPath: String?

    func work(module: borrowing SMModule, placementReport: consuming PlacementReport? = nil, printlevel: PrintLevel) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [ .sortedKeys ]

        // report stats
        var report = FullSynthesisReport()

        // analyze timing and complexity
        if printlevel == .verbose {
            print("Analyzing Design")
        }

        report.timingReport = analyzeTiming(module)
        report.complexityReport = analyzeComplexity(module)
        report.placementReport = placementReport ?? PlacementReport()

        if printlevel == .verbose {
            printTimingReport(report.timingReport)
            printComplexityReport(report.complexityReport)
        } else if printlevel == .lite {
            printLiteReport(report)
        }

        // check difference
        let fileManager = FileManager.default
        let decoder = JSONDecoder()
        if
            printlevel == .verbose, let path = reportPath,
            fileManager.fileExists(atPath: path),
            let data = try? Data(contentsOf: URL(fileURLWithPath: path, isDirectory: false)),
            let oldReport = try? decoder.decode(FullSynthesisReport.self, from: data)
        {
            printDifference(old: oldReport, new: report)
        }

        // write report
        if let path = reportPath {
            let url = URL(fileURLWithPath: path, isDirectory: false)
            let netData = try encoder.encode(report)
            try netData.write(to: url)
            if printlevel == .verbose {
                print("Report written successfully to \"\(path)\"")
            }
        }
    }
}
