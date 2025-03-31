//
//  Flow Command.swift
//  Scrap Mechanic EDA
//

import Foundation
import ArgumentParser

import SMEDANetlist
import SMEDABlueprint
import SMEDAResult

struct FlowCMD: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(commandName: "flow", discussion: "Perform common synthesis steps. Same as running `ys2sm` and `place`.")
    }

    @Flag(name: [.customShort("p"), .customLong("pretty-json")], help: kPrettyPrintArgHelp)
    var prettyPrint: Bool = false

    @Flag(exclusivity: .exclusive, help: kPrintLevelArgHelp)
    var printlevel: PrintLevel = .lite

    @OptionGroup(title: "Transform")
    var transformOptions: TransformArgGroup

    @OptionGroup(title: "Placement")
    var placementOptions: PlacementArgGroup

    @Argument(help: kSrcYSJsonFileArgHelp, completion: .file(extensions: ["json"]))
    var sourceYosysJsonFile: String

    @Argument(help: kOutBPFileArgHelp, completion: .file(extensions: ["json"]))
    var outputBlueprintJsonFile: String

    @Option(name: [.customShort("R"), .customLong("report")],
            help: kOutReportFileArgHelp,
            completion: .file(extensions: ["json"]))
    var outputReportJsonFile: String?

    func run() throws {
        let sourceYosysURL = URL(fileURLWithPath: sourceYosysJsonFile, isDirectory: false)

        let outputBlueprintURL = URL(fileURLWithPath: outputBlueprintJsonFile, isDirectory: false)

        let outputReportURL: URL?
        if let outputReportJsonFile = outputReportJsonFile {
            outputReportURL = URL(fileURLWithPath: outputReportJsonFile, isDirectory: false)
        } else {
            outputReportURL = nil
        }

        // create coders
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        if prettyPrint {
            encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        } else {
            encoder.outputFormatting = [.sortedKeys]
        }

        // load old report (if any)
        let oldReport: FullSynthesisReport?
        if printlevel == .verbose, let oldReportURL = outputReportURL {
            do {
                let data = try Data(contentsOf: oldReportURL)
                oldReport = try decoder.decode(FullSynthesisReport.self, from: data)
            } catch {
                oldReport = nil
            }
        } else {
            oldReport = nil
        }

        // read yosys json
        let yosysData = try Data(contentsOf: sourceYosysURL)

        // parse yosys design
        let design = try decoder.decode(YSDesign.self, from: yosysData)
        if printlevel == .verbose { print("Parsed Yosys Design Successful") }
        let topLevelModule = design.modules.first { Int($0.value.attributes["top"] ?? "0") == 1 }
        guard let (name, ysModule) = topLevelModule else {
            throw ModuleSelectionError.noTopLevelModule
        }
        if printlevel == .verbose { print("Loaded top level module named \"\(name)\"") }

        // create net
        var module = try transform(
            ysModule: ysModule,
            moduleName: name,
            clockDomainNames: transformOptions.clockDomainNames,
            verbose: printlevel == .verbose
        )

        if printlevel == .verbose { print("Transformation Complete") }

        // optimize
        if !transformOptions.noOptimize {
            optimize(&module)
        } else {
            syncClock(&module)
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
