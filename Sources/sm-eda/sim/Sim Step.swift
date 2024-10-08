//
//  Sim Step.swift
//  Scrap Mechanic EDA
//

import Foundation

enum SimStep: Equatable {
    case quit
    case tick(tickCount: UInt32)
    case wrap
    case reset
    case input(constant: UInt64, port: Port)
    case assert(constant: UInt64, port: Port)
    case record
    case stopRecord
    case saveRecord(url: URL)
    case help

    init?(_ string: Substring) {
        let tokens = string.split(separator: " ", omittingEmptySubsequences: true)
        if tokens.isEmpty { return nil }
        switch tokens.first! {
            case "quit":
                guard tokens.count == 1 else {
                    print("Invalid: Command `quit` or `q` does not accept any argument.")
                    return nil
                }
                self = .quit
            case "tick", "t":
                if tokens.count == 1 {
                    self = .tick(tickCount: 1)
                } else if tokens.count == 2, let amount = UInt32(tokens[1]) {
                    self = .tick(tickCount: amount)
                } else {
                    print("Invalid: Usage is `tick/t [<amount>]`")
                    return nil
                }
            case "wrap", "w":
                guard tokens.count == 1 else {
                    print("Invalid: Command `wrap` or `w` does not accept any argument.")
                    return nil
                }
                self = .wrap
            case "reset", "r":
                guard tokens.count == 1 else {
                    print("Invalid: Command `reset` or `r` does not accept any argument.")
                    return nil
                }
                self = .reset
            case "input", "i":
                guard tokens.count == 3,
                      let port = parsePort(argument: tokens[1]),
                      let constant = parseConstant(argument: tokens[2])
                else {
                    print("Invalid: Usage is `input/i port[lsb:msb] <value>` or `input/i port[bit] <value>`")
                    return nil
                }
                self = .input(constant: constant, port: port)
            case "assert", "a":
                guard tokens.count == 3,
                      let port = parsePort(argument: tokens[1]),
                      let constant = parseConstant(argument: tokens[2])
                else {
                    print("Invalid: Usage is `assert/a port[lsb:msb] <value>` or `assert/a port[bit] <value>`")
                    return nil
                }
                self = .assert(constant: constant, port: port)
            case "record":
                guard tokens.count == 1 else {
                    print("Invalid: Command `record` does not accept any argument.")
                    return nil
                }
                self = .record
            case "stop-record", "stop":
                guard tokens.count == 1 else {
                    print("Invalid: Command `stop-record` or `stop` does not accept any argument.")
                    return nil
                }
                self = .stopRecord
            case "save-record", "save":
                let linkString = string
                    .trimmingPrefix(tokens.first!)
                    .trimmingCharacters(in: [" "])
                let url = URL(fileURLWithPath: linkString, isDirectory: false)
                self = .saveRecord(url: url)
            case "help", "h":
                self = .help
            default:
                print("Invalid: Command `\(tokens.first!)` not found. Try `help` instead?")
                return nil
        }
    }
}
