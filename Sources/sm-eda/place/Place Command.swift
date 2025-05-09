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

    @Flag(exclusivity: .exclusive, help: kPrintLevelArgHelp)
    var printlevel: PrintLevel = .lite

    @OptionGroup(title: "Load Module")
    var loadModuleOptions: LoadModuleArgGroup

    @OptionGroup(title: "Load Placement Config")
    var loadConfigOptions: LoadPlacementConfigArgGroup

    @OptionGroup(title: "Placement")
    var placementOptions: PlacementArgGroup

    @OptionGroup(title: "Analyze")
    var analyzeOptions: AnalyzeArgGroup

    func run() throws {
        let module = try loadModuleOptions.work()
        let config = try loadConfigOptions.work()
        let placementReport = try placementOptions.work(module: module, config: config, printlevel: printlevel)
        try analyzeOptions.work(module: module, placementReport: placementReport, printlevel: printlevel)
    }
}
