//
//  Command.swift
//  Scrap Mechanic EDA
//

import Foundation
import ArgumentParser
import SMEDANetlist

private let discussion = "This command can perform editions on a sm netlist file, like merging different modules and connecting (shorting) ports. The edit commands are not specified in the order that they are declared. The order of the commands is `merge`, `connect`, `share`, `drive`, and `remove`"

private let mergeHelp = ArgumentHelp(
    "Merge many netlist into the main netlist.",
    discussion: "Use this option to merge other netlists into this netlist. Inputs and outputs of the imported netlists will be appended to the inputs and outputs of the main netlist. The name of the ports of the imported netlists will be prefixed by their source module name in the form <module>.<port>. The ports of the main module will be unchanged. To wire the imported netlists together, use the \"--connect\" option",
    valueName: "netlists"
)

private let portConnectHelp = ArgumentHelp(
    "Connect output ports back to input ports.",
    discussion: "Use this option to drive input ports using output port values. Parameter is specified by an array of mappings, each in the form of <output-port>[<msb>:<lsb>]-><input-port>[<msb>:<lsb>]. Use this with caution as it may create unintended combinational loops.",
    valueName: "routings"
)

private let portShareHelp = ArgumentHelp(
    "Share input value of one port with another.",
    discussion: "Use this option to share(merge) input ports. Parameter is specified by an array of mappings, each in the form of <input-port>[<msb>:<lsb>]-><input-port>[<msb>:<lsb>].",
    valueName: "routings"
)

private let portDriveHelp = ArgumentHelp(
    "Drive input ports by constant value.",
    discussion: "Use this option to drive input ports using constant value. Parameter is specified by an array of mappings, each in the form of <value>-><input-port>[<msb>:<lsb>]. The <value> contains a integer value of base 10, 16, and 8. Use prefix \"0x\", \"0b\", and \"0o\" to specify the base. Decimal are used when no bases are specified.",
    valueName: "drivers"
)

private let portRemoveHelp = ArgumentHelp(
    "Remove output ports.",
    discussion: "Use this option to remove output ports. Parameter is specified by an array of ports, each in the form of <output-port>[<msb>:<lsb>].",
    valueName: "outputs"
)

private let editScriptHelp = ArgumentHelp(
    "The edit script to run.",
    discussion: "Use this option to specify a text file as the edit script. The file contains a list of commands seperated by new lines and semicolon `;`. Each command is specified in the form of <operation> <argument>. The commands used in scripting is identical to the command line arguments. For example, the script `r A[7:0]` is the same as the command line argument `-r \"A[7:0]\"`. The editing command line arguments will be ignored if a script is specified.",
    valueName: "script-file"
)

struct EditCMD: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(commandName: "edit", discussion: discussion)
    }

    @Flag(exclusivity: .exclusive, help: kPrintLevelArgHelp)
    var printlevel: PrintLevel = .lite

    @Option(name: [.customLong("script")], help: editScriptHelp)
    var scriptFile: String? = nil

    @Option(name: [.customShort("m"), .customLong("merge")], help: mergeHelp,
            completion: .file(extensions: ["json"]))
    var mergeNetlistFiles: [String] = []

    @Option(name: [.customShort("c"), .customLong("connect")], help: portConnectHelp)
    var portConnect: [EditPortRoute] = []

    @Option(name: [.customShort("s"), .customLong("share")], help: portShareHelp)
    var portShare: [EditPortRoute] = []

    @Option(name: [.customShort("d"), .customLong("drive")], help: portDriveHelp)
    var portDrive: [EditPortDrive] = []

    @Option(name: [.customShort("r"), .customLong("remove")], help: portRemoveHelp)
    var portRemove: [EditPort] = []

    @Option(name: [.customShort("n"), .customLong("rename")],
            help: ArgumentHelp("Set name of the output module.", valueName: "new-name"))
    var newName: String? = nil

    @Flag(name: [.customLong("no-opt")])
    var noOptimize: Bool = false

    @Argument(help: kSrcNetFileArgHelp, completion: .file(extensions: ["json"]))
    var inputNetlistFile: String

    @Option(name: [.customShort("O"), .customLong("output")],
            help: kOutOptNetFileArgHelp,
            completion: .file(extensions: ["json"]))
    var outputNetlistFile: String? = nil

    mutating func run() throws {
        // setup
        let fileManager = FileManager.default
        let inputNetlistURL = URL(fileURLWithPath: inputNetlistFile, isDirectory: false)
        let outputNetlistURL: URL
        if let outputNetlistFile = outputNetlistFile {
            outputNetlistURL = URL(fileURLWithPath: outputNetlistFile, isDirectory: false)
        } else {
            outputNetlistURL = inputNetlistURL
        }

        // warn the user if a overwrite will occure
        if printlevel == .verbose, fileManager.fileExists(atPath: outputNetlistFile ?? inputNetlistFile) {
            print("File \"\(outputNetlistURL)\" will be overwritten")
        }

        // create coders
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        encoder.outputFormatting = .sortedKeys

        let function: EditFunction

        // read script
        if let scriptFile = scriptFile {
            // make sure input file exist and readable
            let url = URL(fileURLWithPath: scriptFile)

            // read data
            let data = try Data(contentsOf: url)
            guard let script = String(data: data, encoding: .utf8) else {
                throw CommandError.invalidFormat(fileURL: url)
            }

            // warn inhibit other operands
            let isNop = !mergeNetlistFiles.isEmpty || !portConnect.isEmpty || !portShare.isEmpty || !portDrive.isEmpty || !portRemove.isEmpty
            if printlevel != .none, isNop {
                print("Warning: Edit arguments will be ignored when script file is specified")
            }

            // parse script
            function = try parseScript(script)
        } else {
            let mergeModules = try fetchModule(files: mergeNetlistFiles)
            function = EditFunction(
                merge: mergeModules,
                connect: portConnect,
                share: portShare,
                drive: portDrive,
                remove: portRemove
            )
        }

        // read file
        let netlistData = try Data(contentsOf: inputNetlistURL)
        var module = try decoder.decode(SMModule.self, from: netlistData)

        try function.run(&module)

        // rename
        if let newName = newName {
            module.name = newName
        }

        if !noOptimize {
            optimize(&module)
        }

        // write netlist
        let outData = try encoder.encode(module)
        try outData.write(to: outputNetlistURL)
        if printlevel == .verbose { print("Netlist written successfully to \"\(outputNetlistURL)\"") }
    }
}
