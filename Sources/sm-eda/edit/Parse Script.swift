//
//  Parse Script.swift
//  Scrap Mechanic EDA
//

import Foundation
import ArgumentParser
import SMEDANetlist

func parseScript(_ script: String) throws -> EditFunction {
    var list: [EditCommand] = []

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
                let module = try fetchModule(file: restOfLine)
                list.append(.merge(target: module))
            case "c", "connect":
                guard let arg = EditPortRoute(argument: restOfLine) else {
                    throw EditScriptError.cannotParseScript(line: index, content: trimmedLine)
                }
                list.append(.connect(route: arg))
            case "s", "share":
                guard let arg = EditPortRoute(argument: restOfLine) else {
                    throw EditScriptError.cannotParseScript(line: index, content: trimmedLine)
                }
                list.append(.share(route: arg))
            case "d", "drive":
                guard let arg = EditPortDrive(argument: restOfLine) else {
                    throw EditScriptError.cannotParseScript(line: index, content: trimmedLine)
                }
                list.append(.drive(drive: arg))
            case "r", "remove":
                guard let arg = EditPort(argument: restOfLine) else {
                    throw EditScriptError.cannotParseScript(line: index, content: trimmedLine)
                }
                list.append(.remove(port: arg))
            default:
                throw EditScriptError.cannotParseScript(line: index, content: trimmedLine)
        }
    }

    return EditFunction(commands: list)
}
