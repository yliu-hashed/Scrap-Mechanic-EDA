//
//  Placement Function.swift
//  Scrap Mechanic EDA
//

import Foundation
import ArgumentParser
import SMEDANetlist
import SMEDAResult
import SMEDABlueprint

private let kLZ4PathArgHelp = ArgumentHelp(
    "The path to the LZ4 executable",
    discussion: "Use this parameter to specify the path to LZ4 to accurately estimate blueprint size. If not specified, the path to the LZ4 executable is searched by asking the shell `which lz4`.",
    valueName: "lz4-path"
)

private let kOutBPFileArgHelp = ArgumentHelp(
    "The path of the blueprint json file to write",
    valueName: "out-blueprint"
)

struct PlacementArgGroup: ParsableArguments {

    @Option(name: [.customLong("lz4-path")],
            help: kLZ4PathArgHelp,
            completion: .file())
    var lz4Path: String? = nil

    @Argument(help: kOutBPFileArgHelp, completion: .file(extensions: ["json"]))
    var blueprintFile: String

    func work(module: borrowing SMModule, config: borrowing PlacementConfig, printlevel: PrintLevel) throws -> PlacementReport {
        let fileManager = FileManager.default

        // make sure lz4 can be accessed
        if let lz4Path = lz4Path {
            guard fileManager.isReadableFile(atPath: lz4Path) else {
                throw CommandError.lz4CannotBeAccessed(path: lz4Path)
            }
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [ .sortedKeys ]
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
        if printlevel == .verbose { print("Blueprint written successfully to \"\(blueprintFile)\"") }

        return placementReport
    }
}
