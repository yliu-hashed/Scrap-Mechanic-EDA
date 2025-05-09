//
//  Load Store Module Function.swift
//  Scrap Mechanic EDA
//

import Foundation
import ArgumentParser
import SMEDANetlist

private let kOutNetFileArgHelp = ArgumentHelp(
    "The path of the netlist json file to write",
    valueName: "out-net-json"
)

private let kSrcNetFileArgHelp = ArgumentHelp(
    "The path of the netlist json file to read",
    valueName: "in-net-json"
)

struct LoadModuleArgGroup: ParsableArguments {
    @Argument(help: kSrcNetFileArgHelp, completion: .file(extensions: ["json"]))
    var netlistFile: String

    func work() throws -> SMModule {
        let module = try fetchModule(file: netlistFile)
        try module.check()
        return module
    }
}

struct StoreModuleArgGroup: ParsableArguments {
    @Argument(help: kOutNetFileArgHelp, completion: .file(extensions: ["json"]))
    var netlistFile: String

    func work(module: consuming SMModule, printlevel: PrintLevel) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        let url = URL(fileURLWithPath: netlistFile)
        // write netlist
        let outData = try encoder.encode(module)
        try outData.write(to: url)
        if printlevel == .verbose { print("Netlist written successfully to \"\(netlistFile)\"") }
    }
}
