//
//  Parse Script.swift
//  Scrap Mechanic EDA
//

import Foundation
import ArgumentParser
import SMEDANetlist

func parseScript(_ script: String) throws -> EditFunction {
    var mergeFiles: [String] = []
    var portConnect: [EditPortRoute] = []
    var portShare: [EditPortRoute] = []
    var portDrive: [EditPortDrive] = []
    var portRemove: [EditPort] = []

    let lines = script.split(separator: #/[\n;]+/#, omittingEmptySubsequences: false)
    for (index, line) in lines.enumerated() {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedLine.isEmpty { continue }
        guard let firstSeperator = trimmedLine.firstIndex(of: " ") else {
            throw EditScriptError.cannotParseScript(line: index, content: trimmedLine)
        }
        let firstToken = trimmedLine[..<firstSeperator]
        let restOfLine = trimmedLine[firstSeperator...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        switch firstToken {
            case "m", "merge":
                mergeFiles.append(restOfLine)
            case "c", "connect":
                guard let arg = EditPortRoute(argument: restOfLine) else {
                    throw EditScriptError.cannotParseScript(line: index, content: trimmedLine)
                }
                portConnect.append(arg)
            case "s", "share":
                guard let arg = EditPortRoute(argument: restOfLine) else {
                    throw EditScriptError.cannotParseScript(line: index, content: trimmedLine)
                }
                portShare.append(arg)
            case "d", "drive":
                guard let arg = EditPortDrive(argument: restOfLine) else {
                    throw EditScriptError.cannotParseScript(line: index, content: trimmedLine)
                }
                portDrive.append(arg)
            case "r", "remove":
                guard let arg = EditPort(argument: restOfLine) else {
                    throw EditScriptError.cannotParseScript(line: index, content: trimmedLine)
                }
                portRemove.append(arg)
            default:
                throw EditScriptError.cannotParseScript(line: index, content: trimmedLine)
        }
    }

    // fetch files
    let mergeModules = try fetchModule(files: mergeFiles)

    return EditFunction(
        merge: mergeModules,
        connect: portConnect,
        share: portShare,
        drive: portDrive,
        remove: portRemove
    )
}
