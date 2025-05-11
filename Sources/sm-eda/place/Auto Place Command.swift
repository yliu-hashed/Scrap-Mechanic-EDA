//
//  Auto Place Command.swift
//  Scrap Mechanic EDA
//

import Foundation
import ArgumentParser
import SMEDANetlist
import SMEDAResult
import SMEDABlueprint

struct AutoPlaceCMD: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(commandName: "autoplace", discussion: "Generate blueprint from a netlist file.")
    }

    @Flag(exclusivity: .exclusive, help: kPrintLevelArgHelp)
    var printlevel: PrintLevel = .lite

    @OptionGroup(title: "Load Module")
    var loadModuleOptions: LoadModuleArgGroup

    @OptionGroup(title: "Auto Placement Config")
    var autoPlanOptions: AutoPlanArgGroup

    @OptionGroup(title: "Placement")
    var placementOptions: PlacementArgGroup

    @OptionGroup(title: "Analyze")
    var analyzeOptions: AnalyzeArgGroup

    func run() throws {
        let module = try loadModuleOptions.work()
        let config = try autoPlanOptions.work(module: module)
        let placementReport = try placementOptions.work(module: module, config: config, printlevel: printlevel)
        try analyzeOptions.work(module: module, placementReport: placementReport, printlevel: printlevel)
    }
}
