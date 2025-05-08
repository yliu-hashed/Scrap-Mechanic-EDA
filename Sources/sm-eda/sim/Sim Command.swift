//
//  Sim Command.swift
//  Scrap Mechanic EDA
//

import Foundation
import SMEDANetlist
import ArgumentParser

let subCommandHelp = """
quit|q
    Quit the application
tick|t [<tick>]
    Advance sim time by some specific ticks, or by one tick if not specified
wrap|w
    Time wrap until model become stable (try for 5 seconds)
reset|r
    Reset the internal states and inputs of the model
input|i <port> <value>
input|i <port>[<bit>] <value>
input|i <port>[<msb>:<lsb>] <value>
    Set any input of the netlist
record
    Start input & output recording
stop-record|stop
    Stop recording
save-record|save <path>
    Save recording data as a `.vcd` file to `path`
help
    Print out this help
"""

struct SimCMD: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(commandName: "sim", discussion: "This command perform simulation on a sm netlist file interactively.")
    }

    @OptionGroup(title: "Load Module")
    var loadModuleOptions: LoadModuleArgGroup

    @Option(name: [.customShort("s"), .customLong("script")],
            help: "The path of the script file to run",
            completion: .file(extensions: ["txt"]))
    var inputScriptFile: String? = nil

    func run() throws {
        // print welcome
        print("Welcome to sm-net-sim!")

        // read file
        let netlist = try loadModuleOptions.work()

        let model = SimulationModel(module: netlist)
        let controller = Controller(model: model, isRepl: inputScriptFile == nil)

        // begin repl
        if let inputScriptFile = inputScriptFile {
            let url = URL(fileURLWithPath: inputScriptFile, isDirectory: false)
            let scriptData = try Data(contentsOf: url)
            guard let script = String(data: scriptData, encoding: .utf8) else {
                throw CommandError.invalidFormat(fileURL: url)
            }
            print("Running script `\(inputScriptFile)`")
            try runScript(controller: controller, script: script)
        } else {
            repl(controller: controller)
        }
    }

    func runScript(controller: Controller, script: String) throws {
        let lines = script
            .split(separator: #/[\n\r;]+/#, omittingEmptySubsequences: true)
            .compactMap { substring -> String? in
                let trim = substring.trimmingCharacters(in: [" ", "\t"])
                if trim.isEmpty {
                    return nil
                } else {
                    return trim
                }
            }

        for line in lines {
            guard let command = SimStep(Substring(line)) else {
                throw REPLError.invalidCommand
            }
            controller.run(command: command)
        }
        print("Done")
    }

    func repl(controller: Controller) {
        print("Use `help` to explore possible commands")
        while true {
            guard let line = readLine() else { return }
            guard let command = SimStep(Substring(line)) else { continue }
            if command == .quit { return }
            controller.run(command: command)
        }
    }
}
