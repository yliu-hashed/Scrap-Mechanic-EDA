//
//  SM Color.swift
//  Scrap Mechanic EDA
//

private let validHex: Set<Character> = Set("0123456789ABCDEF")

public enum SMColor {
    case custom(hex: String)
    case paint(shade: SMColorShade, hue: SMColorHue)
    case defaultOrange

    public static let defaultBodyGates:  SMColor = .paint(shade: .veryDark, hue: .gray)
    public static let defaultInputOdd:   SMColor = .paint(shade: .regular,  hue: .green)
    public static let defaultInputEven:  SMColor = .paint(shade: .dark,     hue: .green)
    public static let defaultOutputOdd:  SMColor = .paint(shade: .light,    hue: .gray)
    public static let defaultOutputEven: SMColor = .paint(shade: .regular,  hue: .gray)

    public var hex: String {
        switch self {
            case .custom(let hex):
                return hex
            case .paint(let shade, let hue):
                return hue.getHex(withShade: shade)
            case .defaultOrange:
                return "DF7F01"
        }
    }

    public func validate() -> Bool {
        switch self {
            case .custom(let hex):
                return hex.count == 6 && hex.allSatisfy { validHex.contains($0) }
            default:
                return true
        }
    }
}

public enum SMColorShade: Int, CaseIterable {
    case light    = 0
    case regular  = 1
    case dark     = 2
    case veryDark = 3

    private static let shadeNameTable: [String: SMColorShade] = [
        "dark":      .dark,
        "very dark": .veryDark,
        "light":     .light,
        "bright":    .light
    ]

    static func extractShade(shadeToken: String, hueToken: String) -> SMColorShade? {
        switch hueToken {
            case "white": return .light
            case "black": return .veryDark
            case "brown": return .dark
            default: break
        }
        guard !shadeToken.isEmpty else { return .regular }
        return SMColorShade.shadeNameTable[shadeToken]
    }
}

public enum SMColorHue: String, CaseIterable {
    case gray    = "gray"
    case yellow  = "yellow"
    case lime    = "lime"
    case green   = "green"
    case cyan    = "cyan"
    case blue    = "blue"
    case violet  = "violet"
    case magenta = "magenta"
    case red     = "red"
    case orange  = "orange"

    static func extractHue(hueToken: String) -> SMColorHue? {
        let hueName: String
        if let equiv = SMColorHue.hueEquavalence[hueToken] {
            hueName = equiv
        } else {
            hueName = hueToken
        }
        if let hue = SMColorHue(rawValue: hueName) {
            return hue
        } else {
            return nil
        }
    }

    private static let colorTable: [SMColorHue: [String]] = [
        .gray:    ["EEEEEE", "7F7F7F", "4A4A4A", "222222"],
        .yellow:  ["F5F071", "E2DB13", "817C00", "323000"],
        .lime:    ["CBF66F", "A0EA00", "577D07", "375000"],
        .green:   ["68FF88", "19E753", "0E8031", "064023"],
        .cyan:    ["7EEDED", "2CE6E6", "118787", "0A4444"],
        .blue:    ["4C6FE3", "0A3EE2", "0F2E91", "0A1D5A"],
        .violet:  ["AE79F0", "7514ED", "500AA6", "35086C"],
        .magenta: ["EE7BF0", "CF11D2", "720A74", "520653"],
        .red:     ["F06767", "D02525", "7C0000", "560202"],
        .orange:  ["EEAF5C", "DF7F00", "673B00", "472800"]
    ]

    private static let hueEquavalence: [String: String] = [
        "white"  : "gray",
        "black"  : "gray",
        "purple" : "violet",
        "brown"  : "orange"
    ]

    func getHex(withShade shade: SMColorShade) -> String {
        return SMColorHue.colorTable[self]![shade.rawValue]
    }
}

public func extractColor(literal: String) -> SMColor? {
    if literal.hasPrefix("#"), literal.count == 7,
       literal.suffix(6).allSatisfy({ validHex.contains($0) }) {
        return .custom(hex: String(literal.suffix(6)))
    }

    let lowerLiteral = literal.lowercased()
    let tokens = lowerLiteral.split(separator: " ")
    guard tokens.count >= 1 else { return nil }

    let shadeToken = tokens.dropLast().joined(separator: " ")
    let hueToken = String(tokens.last!)

    guard let hue = SMColorHue.extractHue(hueToken: hueToken),
          let shade = SMColorShade.extractShade(shadeToken: shadeToken, hueToken: hueToken)
    else { return nil }

    return .paint(shade: shade, hue: hue)
}
