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
        // Guard against invalid input
        let sizeConstraint = 64
        if let blueprintDepth = placementOptions.blueprintDepth {
            guard blueprintDepth > 0, blueprintDepth <= sizeConstraint else {
                throw CommandError.invalidInput(description: "blueprint depth must be within 1...\(sizeConstraint)")
            }
        }
        if let blueprintWidth = placementOptions.blueprintWidth {
            guard blueprintWidth > 0, blueprintWidth <= sizeConstraint else {
                throw CommandError.invalidInput(description: "blueprint wrapping must be within 1...\(sizeConstraint)")
            }
        }

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
        if prettyPrint {
            encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        } else {
            encoder.outputFormatting = [.sortedKeys]
        }

        let module = try fetchModule(file: sourceNetJsonFile)
        try module.check()

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

        // place blueprint
        if printlevel == .verbose { print("Placing Blueprint") }
        let blueprint = try simplePlace(
            module,
            defaultInputDevice: placementOptions.inputDeviceType.device,
            depth: placementOptions.blueprintDepth,
            widthWrap: placementOptions.blueprintWidth,
            portLocation: placementOptions.portLocation,
            packPort: placementOptions.packPort,
            facade: !placementOptions.noFacade,
            report: &report.placementReport,
            doPrint: printlevel == .verbose || outputReportURL == nil
        )
        if printlevel == .verbose { print("Blueprint Generation Successfully") }

        // check size & write blueprint
        let blueprintData = try encoder.encode(blueprint)
        checkSize(
            data: blueprintData,
            facade: !placementOptions.noFacade,
            report: &report.placementReport,
            verbose: printlevel == .verbose,
            lz4Path: placementOptions.lz4Path
        )
        try blueprintData.write(to: outputBlueprintURL)
        if printlevel == .verbose { print("Blueprint written successfully to \"\(outputBlueprintURL)\"") }

        // write report
        if let outputReportURL = outputReportURL {
            let netData = try encoder.encode(report)
            try netData.write(to: outputReportURL)
            if printlevel == .verbose { print("Report written successfully to \"\(outputReportURL)\"") }
        }
    }
}
