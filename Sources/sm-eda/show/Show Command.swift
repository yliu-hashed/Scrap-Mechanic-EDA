//
//  Show Command.swift
//  Scrap Mechanic EDA
//

import Foundation
import SMEDANetlist
import ArgumentParser
private let outputDotFileArgHelp = ArgumentHelp(
    "The path of the .dot file to write",
    discussion: "If not specified, file will be printed to stdout instead.",
    valueName: "path"
)

struct ShowCMD: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(commandName: "show", discussion: "This command generate .dot file from a netlist.")
    }

    @Argument(help: "The path of the netlist file to read",
              completion: .file(extensions: ["json"]))
    var inputNetlistFile: String

    @Flag(help: "Show gate id for each gate in the netlist")
    var showID: Bool = false

    @Option(name: [.customShort("O"), .customLong("output")],
            help: outputDotFileArgHelp, 
            completion: .file(extensions: ["dot", "txt"]))
    var outputDotFile: String? = nil

    func run() throws {
        // setup
        let inputNetlistURL = URL(fileURLWithPath: inputNetlistFile, isDirectory: false)

        // create coders
        let decoder = JSONDecoder()

        // read file
        let netlistData = try Data(contentsOf: inputNetlistURL)
        let netlist = try decoder.decode(SMModule.self, from: netlistData)

        // generate dot file
        let dotFile = showDot(module: netlist, showID: showID)

        // store or print
        if let outputDotFile = outputDotFile {
            let outputDotURL = URL(fileURLWithPath: outputDotFile, isDirectory: false)
            let dotData = dotFile.data(using: .utf8)!
            try dotData.write(to: outputDotURL)
            print("Dot file written successfully to \"\(outputDotURL)\"")
        } else {
            print(dotFile)
        }
    }
}
