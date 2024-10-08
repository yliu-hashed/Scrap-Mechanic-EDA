//
//  Errors.swift
//  Scrap Mechanic EDA
//

import Foundation

public enum EditScriptError: Error, CustomStringConvertible {
    case cannotParseScript(line: Int, content: String)

    public var description: String {
        switch self {
            case .cannotParseScript(let line, let content):
                return "Cannot parse line \(line) `\(content)`"
        }
    }
}
