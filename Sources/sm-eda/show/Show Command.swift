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

    @OptionGroup(title: "Load Module")
    var loadModuleOptions: LoadModuleArgGroup

    @Flag(help: "Show gate id for each gate in the netlist")
    var showID: Bool = false

    @Option(name: [.customShort("O"), .customLong("output")],
            help: outputDotFileArgHelp, 
            completion: .file(extensions: ["dot", "txt"]))
    var outputDotFile: String? = nil

    func run() throws {
        // load module
        let module = try loadModuleOptions.work()

        // generate dot file
        let dotFile = showDot(module: module, showID: showID)

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
