//
//  Extensions.swift
//  Scrap Mechanic EDA
//

import Foundation
import ArgumentParser
import SMEDANetlist

extension BRAMPortConfig: ExpressibleByArgument {}

extension EditPort: ExpressibleByArgument {
    public init?(argument: String) {
        let matchPortRegex = #/([0-9a-zA-Z-_.]+)\[([0-9]+)\:([0-9]+)\]/#

        guard let match = try? matchPortRegex.wholeMatch(in: argument),
              let msb = Int(match.2),
              let lsb = Int(match.3)
        else { return nil }
        self = EditPort(port: String(match.1), msb: msb, lsb: lsb)
    }
}

extension EditPortRoute: ExpressibleByArgument {
    public init?(argument: String) {
        let matchArrowRegex = #/([a-zA-Z0-9-_.:\[\]]+)->([a-zA-Z0-9-_.:\[\]]+)/#
        guard let match = try? matchArrowRegex.wholeMatch(in: argument),
              let srcPort = EditPort(argument: String(match.1)),
              let dstPort = EditPort(argument: String(match.2))
        else { return nil }

        self = EditPortRoute(srcPort: srcPort, dstPort: dstPort)
    }
}

extension EditPortDrive: ExpressibleByArgument {
    public init?(argument: String) {
        let matchArrowRegex = #/([a-zA-Z0-9-_.:\[\]]+)->([a-zA-Z0-9-_.:\[\]]+)/#
        let matchConstRegex = #/(0x|0b|0d|0o|)([0-9a-fA-F]+)/#

        // match
        guard let matchArrow = try? matchArrowRegex.wholeMatch(in: argument),
              let matchConst = try? matchConstRegex.wholeMatch(in: matchArrow.1),
              let dstPort = EditPort(argument: String(matchArrow.2))
        else { return nil }

        // decode constant
        let constDecode: UInt64?
        switch matchConst.1 {
            case "", "0d": constDecode = UInt64(matchConst.2)
            case     "0x": constDecode = UInt64(matchConst.2, radix: 16)
            case     "0o": constDecode = UInt64(matchConst.2, radix: 8)
            case     "0b": constDecode = UInt64(matchConst.2, radix: 2)
            default: return nil
        }
        guard let constant = constDecode else { return nil }

        self = EditPortDrive(constant: constant, dstPort: dstPort)
    }
}
