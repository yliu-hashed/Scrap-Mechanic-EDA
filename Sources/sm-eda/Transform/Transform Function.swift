//
//  Arg Group.swift
//  Scrap Mechanic EDA
//

import Foundation
import ArgumentParser
import SMEDANetlist

struct TransformArgGroup: ParsableArguments {
    @Option(name: [.customLong("clk")], help: kClockDomainArgHelp)
    var clockDomainNames: [String] = []

    @Argument(help: kSrcYSJsonFileArgHelp, completion: .file(extensions: ["json"]))
    var yosysFilePath: String

    func work(printlevel: PrintLevel) throws -> SMModule {
        let decoder = JSONDecoder()

        // read yosys json
        let yosysJsonURL = URL(fileURLWithPath: yosysFilePath, isDirectory: false)
        let yosysData = try Data(contentsOf: yosysJsonURL)
        let design = try decoder.decode(YSDesign.self, from: yosysData)
        if printlevel == .verbose {
            print("Parsed Yosys Design Successful")
        }

        // identify top level module
        let topLevelModule = design.modules.first { Int($0.value.attributes["top"] ?? "0") == 1 }
        guard let (name, ysModule) = topLevelModule else {
            throw ModuleSelectionError.noTopLevelModule
        }
        if printlevel == .verbose {
            print("Loaded top level module named \"\(name)\"")
        }

        // transform into SMModule
        let module = try transform(
            ysModule: ysModule,
            moduleName: name,
            clockDomainNames: clockDomainNames,
            verbose: printlevel == .verbose
        )

        if printlevel == .verbose {
            print("Transformation Complete")
        }

        return module
    }
}
