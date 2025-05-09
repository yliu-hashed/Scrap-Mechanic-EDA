//
//  Load Store Placement Config Function.swift
//  Scrap Mechanic EDA
//

import Foundation
import ArgumentParser
import SMEDANetlist

private let kConfigArgHelp = ArgumentHelp(
    "The placement configuration for the module",
    discussion: "Use this option to influence the placement of the module. The placement configuration is a JSON file that defines the placement rules for the module. When this option is specified, the module placement is only determined by the rules defined in the JSON file, and command line options are ignored.",
    valueName: "config"
)

private let kOutPlacementConfigFileArgHelp = ArgumentHelp(
    "The path of the placement config json file to write",
    valueName: "out-config-json"
)

struct LoadPlacementConfigArgGroup: ParsableArguments {
    @Option(name: [.customShort("c"), .customLong("config")],
            help: kConfigArgHelp,
            completion: .file(extensions: ["json"]))
    var configFile: String

    func work() throws -> PlacementConfig {
        return try fetchPlacementConfig(file: configFile)
    }
}

struct StorePlacementConfigArgGroup: ParsableArguments {
    @Argument(help: kOutPlacementConfigFileArgHelp,
              completion: .file(extensions: ["json"]))
    var configFile: String

    func work(config: consuming PlacementConfig, printlevel: PrintLevel) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]

        let url = URL(fileURLWithPath: configFile)
        // write netlist
        let outData = try encoder.encode(config)
        try outData.write(to: url)
        if printlevel == .verbose { print("Placement Config written successfully to \"\(configFile)\"") }
    }
}
