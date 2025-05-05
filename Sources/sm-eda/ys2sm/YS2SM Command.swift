//
//  YS2SM Command.swift
//  Scrap Mechanic EDA
//

import Foundation
import ArgumentParser

import SMEDANetlist
import SMEDABlueprint
import SMEDAResult

struct YS2SMCMD: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(commandName: "ys2sm", discussion: "Convert a Yosys json file to a netlist file.")
    }

    @Flag(name: [.customShort("p"), .customLong("pretty-json")], help: kPrettyPrintArgHelp)
    var prettyPrint: Bool = false

    @Flag(exclusivity: .exclusive, help: kPrintLevelArgHelp)
    var printlevel: PrintLevel = .lite

    @OptionGroup(title: "Transform")
    var transformOptions: TransformArgGroup

    @Argument(help: kSrcYSJsonFileArgHelp, completion: .file(extensions: ["json"]))
    var sourceYosysJsonFile: String

    @Argument(help: kOutNetFileArgHelp, completion: .file(extensions: ["json"]))
    var outputNetJsonFile: String

    @Option(name: [.customShort("R"), .customLong("report")],
            help: kOutReportFileArgHelp,
            completion: .file(extensions: ["json"]))
    var outputReportJsonFile: String?

    func run() throws {
        let sourceYosysURL = URL(fileURLWithPath: sourceYosysJsonFile, isDirectory: false)

        let outputNetURL = URL(fileURLWithPath: outputNetJsonFile, isDirectory: false)

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

        // report status
        var report = FullSynthesisReport()
        // analyze timing
        if printlevel == .verbose {
            print("Analyzing Design")
        }

        report.timingReport = analyzeTiming(module)
        report.complexityReport = analyzeComplexity(module)

        if printlevel == .verbose {
            printTimingReport(report.timingReport)
            printComplexityReport(report.complexityReport)
        } else if printlevel == .lite {
            printLiteReport(report)
        }

        let data = try encoder.encode(module)
        try data.write(to: outputNetURL)
        if printlevel == .verbose { print("Net written successfully to \"\(outputNetURL)\"") }

        // write report
        if let outputReportURL = outputReportURL {
            let netData = try encoder.encode(report)
            try netData.write(to: outputReportURL)
            if printlevel == .verbose { print("Report written successfully to \"\(outputReportURL)\"") }
        }
    }
}
