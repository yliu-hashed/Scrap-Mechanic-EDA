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

    @Flag(exclusivity: .exclusive, help: kPrintLevelArgHelp)
    var printlevel: PrintLevel = .lite

    @OptionGroup(title: "Transform")
    var transformOptions: TransformArgGroup

    @OptionGroup(title: "Optimize")
    var optimizerOptions: OptimizerArgGroup

    @OptionGroup(title: "Store Module")
    var storeModuleOptions: StoreModuleArgGroup

    @OptionGroup(title: "Analyze")
    var analyzeOptions: AnalyzeArgGroup

    func run() throws {
        var module = try transformOptions.work(printlevel: printlevel)

        try optimizerOptions.work(module: &module)

        try storeModuleOptions.work(module: module, printlevel: printlevel)

        try analyzeOptions.work(module: module, printlevel: printlevel)
    }
}
