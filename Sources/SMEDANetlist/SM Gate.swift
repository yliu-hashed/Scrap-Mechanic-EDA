//
//  SM Gate.swift
//  Scrap Mechanic EDA
//

public struct SMGate: Codable, Equatable, Hashable {
    public var type: SMGateType
    public var srcs: Set<UInt64>
    public var dsts: Set<UInt64>
    public var portalSrcs: [UInt64: Int]
    public var portalDsts: [UInt64: Int]

    public var hasPortals: Bool { !portalSrcs.isEmpty || !portalDsts.isEmpty }

    public init(
        type: SMGateType,
        srcs: Set<UInt64> = [],
        dsts: Set<UInt64> = [],
        portalSrcs: [UInt64: Int] = [:],
        portalDsts: [UInt64: Int] = [:]
    ) {
        self.type = type
        self.srcs = srcs
        self.dsts = dsts
        self.portalSrcs = portalSrcs
        self.portalDsts = portalDsts
    }

    enum CodingKeys: CodingKey {
        case type
        case srcs
        case dsts
        case portalSrcs
        case portalDsts
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(srcs, forKey: .srcs)
        try container.encode(dsts, forKey: .dsts)
        if !portalSrcs.isEmpty { try container.encode(portalSrcs, forKey: .portalSrcs) }
        if !portalDsts.isEmpty { try container.encode(portalDsts, forKey: .portalDsts) }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(SMGateType.self, forKey: .type)
        self.srcs = try container.decode(Set<UInt64>.self, forKey: .srcs)
        self.dsts = try container.decode(Set<UInt64>.self, forKey: .dsts)
        self.portalSrcs = try container.decodeIfPresent([UInt64: Int].self, forKey: .portalSrcs) ?? [:]
        self.portalDsts = try container.decodeIfPresent([UInt64: Int].self, forKey: .portalDsts) ?? [:]
    }
}

public enum SMGateGroup: Int, Equatable, Hashable, CaseIterable, CustomStringConvertible {
    case and  = 0
    case or   = 1
    case xor  = 2
    case nand = 3
    case nor  = 4
    case xnor = 5
    case timer = -1

    public var description: String {
        switch self {
            case .and:   return "AND"
            case .or:    return "OR"
            case .xor:   return "XOR"
            case .nand:  return "NAND"
            case .nor:   return "NOR"
            case .xnor:  return "XNOR"
            case .timer: return "TIMER"
        }
    }
}

public enum SMGateType: Codable, Equatable, Hashable {
    case logic(type: SMLogicType)
    case timer(delay: Int)

    public var group: SMGateGroup {
        switch self {
            case .logic(let type):
                return SMGateGroup(rawValue: type.rawValue)!
            case .timer(_):
                return .timer
        }
    }
}

public enum SMLogicType: Int, Codable, CaseIterable {
    case and  = 0
    case or   = 1
    case xor  = 2
    case nand = 3
    case nor  = 4
    case xnor = 5
}
