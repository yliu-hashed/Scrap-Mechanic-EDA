//
//  Arg Group.swift
//  Scrap Mechanic EDA
//

import Foundation
import ArgumentParser
import SMEDANetlist

private let kSrcYSJsonFileArgHelp = ArgumentHelp(
    "The path of the yosys json file to read",
    discussion: "SM-EDA uses Yosys as its detached HDL frontend. Use `write_json` in Yosys to generate a json file.",
    valueName: "in-yosys-json"
)

private let kClockDomainArgHelp = ArgumentHelp(
    "The clock domain of the design",
    discussion: "Repeat the same argument to specify multiple clock domains.",
    valueName: "clock-domain"
)

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
