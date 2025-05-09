//
//  Load Store Placement Config Function.swift
//  Scrap Mechanic EDA
//

import Foundation
import ArgumentParser
import SMEDANetlist

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
