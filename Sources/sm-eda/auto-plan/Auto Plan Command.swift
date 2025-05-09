//
//  Auto Plan Command.swift
//  Scrap Mechanic EDA
//

import ArgumentParser
import SMEDANetlist

struct AutoPlanCMD: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(commandName: "autoplan", discussion: "Generate a basic Placement Configuration.")
    }

    @Flag(exclusivity: .exclusive, help: kPrintLevelArgHelp)
    var printlevel: PrintLevel = .lite

    @OptionGroup(title: "Load Module")
    var loadModuleOptions: LoadModuleArgGroup

    @OptionGroup(title: "Auto Planning")
    var autoPlanOptions: AutoPlanArgGroup

    @OptionGroup(title: "Store Placement Config")
    var storeConfigOptions: StorePlacementConfigArgGroup

    func run() throws {
        let module = try loadModuleOptions.work()
        let config = try autoPlanOptions.work(module: module)
        try storeConfigOptions.work(config: config, printlevel: printlevel)
    }
}
