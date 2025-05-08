//
//  Arg Group.swift
//  Scrap Mechanic EDA
//

import ArgumentParser
import SMEDABlueprint

struct PlacementArgGroup: ParsableArguments {
    @Option(name: [.customShort("c"), .customLong("config")],
            help: kConfigArgHelp,
            completion: .file(extensions: ["json"]))
    var config: String

    @Option(name: [.customLong("lz4-path")],
            help: kLZ4PathArgHelp,
            completion: .file())
    var lz4Path: String? = nil
}

struct TransformArgGroup: ParsableArguments {
    @Flag(name: [.customLong("no-opt")])
    var noOptimize: Bool = false

    @Option(name: [.customLong("clk")], help: kClockDomainArgHelp)
    var clockDomainNames: [String] = []
}
