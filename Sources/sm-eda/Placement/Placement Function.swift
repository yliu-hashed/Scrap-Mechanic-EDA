//
//  Placement Function.swift
//  Scrap Mechanic EDA
//

import Foundation
import ArgumentParser
import SMEDANetlist
import SMEDAResult
import SMEDABlueprint

struct PlacementArgGroup: ParsableArguments {
    @Option(name: [.customShort("c"), .customLong("config")],
            help: kConfigArgHelp,
            completion: .file(extensions: ["json"]))
    var configPath: String

    @Option(name: [.customLong("lz4-path")],
            help: kLZ4PathArgHelp,
            completion: .file())
    var lz4Path: String? = nil

    @Argument(help: kOutBPFileArgHelp, completion: .file(extensions: ["json"]))
    var blueprintFile: String

    func work(module: borrowing SMModule, printlevel: PrintLevel) throws -> PlacementReport {
        let fileManager = FileManager.default

        // make sure lz4 can be accessed
        if let lz4Path = lz4Path {
            guard fileManager.isReadableFile(atPath: lz4Path) else {
                throw CommandError.lz4CannotBeAccessed(path: lz4Path)
            }
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [ .sortedKeys ]
        // load port configs
        let config = try fetchPlacementConfig(file: configPath)

        // place blueprint
        if printlevel == .verbose { print("Placing Blueprint") }
        var placementReport = PlacementReport()
        let blueprint = try place(module, config: config, report: &placementReport)
        if printlevel == .verbose { print("Blueprint Generation Successfully") }

        // check size & write blueprint
        let blueprintData = try encoder.encode(blueprint)
        checkSize(
            data: blueprintData,
            facade: config.facade,
            report: &placementReport,
            verbose: printlevel == .verbose,
            lz4Path: lz4Path
        )
        try blueprintData.write(to: URL(fileURLWithPath: blueprintFile, isDirectory: false))
        if printlevel == .verbose { print("Blueprint written successfully to \"\(configPath)\"") }

        return placementReport
    }
}
