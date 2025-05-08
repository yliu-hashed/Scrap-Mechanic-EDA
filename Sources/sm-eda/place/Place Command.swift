//
//  Place Command.swift
//  Scrap Mechanic EDA
//

import Foundation
import ArgumentParser
import SMEDANetlist
import SMEDAResult
import SMEDABlueprint

struct PlaceCMD: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(commandName: "place", discussion: "Generate blueprint from a netlist file.")
    }

    @Flag(name: [.customShort("p"), .customLong("pretty-json")], help: kPrettyPrintArgHelp)
    var prettyPrint: Bool = false

    @Flag(exclusivity: .exclusive, help: kPrintLevelArgHelp)
    var printlevel: PrintLevel = .lite

    @OptionGroup(title: "Placement")
    var placementOptions: PlacementArgGroup

    @Argument(help: kSrcNetFileArgHelp, completion: .file(extensions: ["json"]))
    var sourceNetJsonFile: String

    @Argument(help: kOutBPFileArgHelp, completion: .file(extensions: ["json"]))
    var outputBlueprintJsonFile: String

    @Option(name: [.customShort("R"), .customLong("report")],
            help: kOutReportFileArgHelp,
            completion: .file(extensions: ["json"]))
    var outputReportJsonFile: String?

    func run() throws {
        // form URL
        let fileManager = FileManager.default

        let outputBlueprintURL = URL(fileURLWithPath: outputBlueprintJsonFile, isDirectory: false)

        let outputReportURL: URL?
        if let outputReportJsonFile = outputReportJsonFile {
            outputReportURL = URL(fileURLWithPath: outputReportJsonFile, isDirectory: false)
        } else {
            outputReportURL = nil
        }

        // make sure lz4 can be accessed
        if let lz4Path = placementOptions.lz4Path {
            guard fileManager.isReadableFile(atPath: lz4Path) else {
                throw CommandError.lz4CannotBeAccessed(path: lz4Path)
            }
        }

        // create coders
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        if prettyPrint {
            encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        } else {
            encoder.outputFormatting = [.sortedKeys]
        }

        let module = try fetchModule(file: sourceNetJsonFile)
        try module.check()

        // load old report (if any)
        let oldReport: FullSynthesisReport?
        if printlevel == .verbose, let oldReportURL = outputReportURL, fileManager.fileExists(atPath: oldReportURL.path()) {
            do {
                let data = try Data(contentsOf: oldReportURL)
                oldReport = try decoder.decode(FullSynthesisReport.self, from: data)
            } catch {
                oldReport = nil
            }
        } else {
            oldReport = nil
        }

        // report stats
        var report = FullSynthesisReport()

        // analyze timing and complexity
        if printlevel == .verbose {
            print("Analyzing Design (Post-Optimization)")
        }

        report.timingReport = analyzeTiming(module)
        report.complexityReport = analyzeComplexity(module)

        if printlevel == .verbose {
            printTimingReport(report.timingReport)
            printComplexityReport(report.complexityReport)
        } else if printlevel == .lite {
            printLiteReport(report)
        }

        // load port configs
        let config = try fetchPlacementConfig(file: placementOptions.config)

        // place blueprint
        if printlevel == .verbose { print("Placing Blueprint") }
        let blueprint = try place(module, config: config, report: &report.placementReport)
        if printlevel == .verbose { print("Blueprint Generation Successfully") }

        // check size & write blueprint
        let blueprintData = try encoder.encode(blueprint)
        checkSize(
            data: blueprintData,
            facade: config.facade,
            report: &report.placementReport,
            verbose: printlevel == .verbose,
            lz4Path: placementOptions.lz4Path
        )
        try blueprintData.write(to: outputBlueprintURL)
        if printlevel == .verbose { print("Blueprint written successfully to \"\(outputBlueprintURL)\"") }

        // check difference
        if printlevel == .verbose, let old = oldReport {
            printDifference(old: old, new: report)
        }

        // write report
        if let outputReportURL = outputReportURL {
            let netData = try encoder.encode(report)
            try netData.write(to: outputReportURL)
            if printlevel == .verbose { print("Report written successfully to \"\(outputReportURL)\"") }
        }
    }
}
