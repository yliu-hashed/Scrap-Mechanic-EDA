//
//  Printing Utilities.swift
//  Scrap Mechanic EDA
//

import Foundation
import SMEDANetlist

func printItems(
    title: String = "",
    _ table: [(key: String, value: String)],
    numbered: Bool,
    minKeyWidth: Int = 25
) {
    print(title + ":")
    var maxKey: Int = max(minKeyWidth, 0)
    for (key, _) in table {
        maxKey = max(key.count, maxKey)
    }
    if numbered {
        let digits = "\(table.count)".count
        for (index, (key, value)) in table.enumerated() {
            let prefix = (index + 1).description.padding(to: digits, left: true)
            let key = (key + ":").padding(to: maxKey - digits)
            print("   \(prefix). \(key) \(value)")
        }
    } else {
        for (key, value) in table {
            let key = (key + ":").padding(to: maxKey + 2)
            print("   \(key) \(value)")
        }
    }
}

func timeFromTicks(_ time: Int?, nilName: String = "--") -> String {
    if let time = time {
        let realTime = (Float(time) / Float(kSMFrameRate))
        return "\(time.description) (\(realTime)s)"
    } else {
        return nilName
    }
}

enum PrintingPurpose {
    case warning
    case error

    var color: ANSIColor {
        switch self {
        case .warning:
            return ANSIColor.yellow
        case .error:
            return ANSIColor.red
        }
    }

    var prefix: String {
        switch self {
        case .warning:
            return "Warning: "
        case .error:
            return "Error: "
        }
    }

    var printingPrefix: String {
        if terminalSupportsColor {
            return color.wrap(around: prefix)
        } else {
            return prefix
        }
    }
}

func print(for purpose: PrintingPurpose, _ string: consuming String) {
    switch purpose {
    case .warning:
        setPrintColor(to: .yellow)
        print("Warning:", terminator: " ")
    case .error:
        setPrintColor(to: .red)
        print("Error:", terminator: " ")
    }
    setPrintColor(to: .default)
    print(string)
}

enum ANSIColor: String {
    case black = "\u{001B}[0;30m"
    case red = "\u{001B}[0;31m"
    case green = "\u{001B}[0;32m"
    case yellow = "\u{001B}[0;33m"
    case blue = "\u{001B}[0;34m"
    case magenta = "\u{001B}[0;35m"
    case cyan = "\u{001B}[0;36m"
    case white = "\u{001B}[0;37m"
    case `default` = "\u{001B}[0;0m"

    func wrap(around string: String) -> String {
        return "\(rawValue)\(string)\(ANSIColor.default.rawValue)"
    }
}

func setPrintColor(to color: ANSIColor) {
    if terminalSupportsColor {
        print(color.rawValue, terminator: "")
    }
}

let terminalSupportsColor: Bool = detectTerminalColor()

private func detectTerminalColor() -> Bool {
    let term = ProcessInfo.processInfo.environment["TERM"]?.lowercased() ?? ""
    let colorterm = ProcessInfo.processInfo.environment["COLORTERM"]?.lowercased() ?? ""
    return term.contains("color") || colorterm.contains("color")
}
