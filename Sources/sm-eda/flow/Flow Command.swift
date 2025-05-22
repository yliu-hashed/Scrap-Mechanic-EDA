//
//  Flow Command.swift
//  Scrap Mechanic EDA
//

import Foundation
import ArgumentParser

import SMEDANetlist
import SMEDABlueprint
import SMEDAResult

struct FlowCMD: AsyncParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(commandName: "flow", discussion: "Perform the common synthesis steps. This is the entry point for most users. This commands takes a Yosys netlist file, transforms it into a SMEDA netlist module, then performs the auto planning, placement and analysis steps.")
    }

    @Flag(exclusivity: .exclusive, help: kPrintLevelArgHelp)
    var printlevel: PrintLevel = .lite

    @OptionGroup(title: "Transform")
    var transformOptions: TransformArgGroup

    @OptionGroup(title: "Optimize")
    var optimizerOptions: OptimizerArgGroup

    @OptionGroup(title: "Auto Planning")
    var autoPlanOptions: AutoPlanArgGroup

    @OptionGroup(title: "Placement")
    var placementOptions: PlacementArgGroup

    @OptionGroup(title: "Analyze")
    var analyzeOptions: AnalyzeArgGroup

    func run() async throws {
        var module = try transformOptions.work(printlevel: printlevel)
        try optimizerOptions.work(module: &module)
        let config = try autoPlanOptions.work(module: module)
        let placementReport = try await placementOptions.work(module: module, config: config, printlevel: printlevel)
        try analyzeOptions.work(module: module, placementReport: placementReport, printlevel: printlevel)
    }
}
