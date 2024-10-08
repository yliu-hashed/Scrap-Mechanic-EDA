//
//  Sim Parse Input Port.swift
//  Scrap Mechanic EDA
//

struct Port: Equatable {
    var port: String
    var msb: Int
    var lsb: Int

    var width: Int { msb - lsb + 1 }
    var isAll: Bool { msb == .max && lsb == .min }

    init(port: String, msb: Int, lsb: Int) {
        self.port = port
        self.msb = msb
        self.lsb = lsb
    }
}

func parsePort(argument: Substring) -> Port? {
    let matchPortRangeRegex = #/([0-9a-zA-Z-_.]+)\[([0-9]+)\:([0-9]+)\]/#
    let matchPortBitRegex = #/([0-9a-zA-Z-_.]+)\[([0-9]+)\]/#
    let matchPortRegex = #/([0-9a-zA-Z-_.]+)/#

    if let match = try? matchPortRangeRegex.wholeMatch(in: argument) {
        guard let msb = Int(match.2),
              let lsb = Int(match.3)
        else { return nil }

        return Port(port: String(match.1), msb: msb, lsb: lsb)
    }

    if let match = try? matchPortBitRegex.wholeMatch(in: argument) {
        guard let bit = Int(match.2) else { return nil }

        return Port(port: String(match.1), msb: bit, lsb: bit)
    }

    if let match = try? matchPortRegex.wholeMatch(in: argument) {
        return Port(port: String(match.1), msb: .max, lsb: .min)
    }

    return nil
}

func parseConstant(argument: Substring) -> UInt64? {
    let matchConstRegex = #/(0x|0b|0d|0o|)([0-9a-fA-F]+)/#
    guard let matchConst = try? matchConstRegex.wholeMatch(in: argument)
    else { return nil }

    let constDecode: UInt64?
    switch matchConst.1 {
        case "", "0d": constDecode = UInt64(matchConst.2)
        case     "0x": constDecode = UInt64(matchConst.2, radix: 16)
        case     "0o": constDecode = UInt64(matchConst.2, radix: 8)
        case     "0b": constDecode = UInt64(matchConst.2, radix: 2)
        default: return nil
    }
    return constDecode
}
