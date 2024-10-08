//
//  YS Module.swift
//  Scrap Mechanic EDA
//

import SMEDANetlist

struct YSDesign: Decodable {
    var creator: String
    var modules: [String: YSModule]

    enum CodingKeys: String, CodingKey {
        case creator
        case modules
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.creator = try container.decode(String.self, forKey: .creator)
        self.modules = try container.decode([String: YSModule].self, forKey: .modules)
    }
}

struct YSModule: Decodable {
    var attributes: [String: String]
    /// Parameter Default Values
    var defaults: [String: String]
    var ports: [String: YSPort]
    var cells: [String: YSCell]
    var netNames: [String: YSNetName]

    enum CodingKeys: String, CodingKey {
        case attributes = "attributes"
        case defaults = "parameter_default_values"
        case ports = "ports"
        case cells = "cells"
        case netNames = "netnames"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        attributes = try container.decodeIfPresent([String: String].self, forKey: .attributes) ?? [:]
        defaults = try container.decodeIfPresent([String: String].self, forKey: .defaults) ?? [:]
        ports = try container.decodeIfPresent([String: YSPort].self, forKey: .ports) ?? [:]
        cells = try container.decodeIfPresent([String: YSCell].self, forKey: .cells) ?? [:]
        netNames = try container.decodeIfPresent([String: YSNetName].self, forKey: .netNames) ?? [:]
    }
}

enum YSBit: Decodable, Equatable {
    case shared(id: UInt64)
    case fixed(state: Bool)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .fixed(state: string == "1")
        } else if let integer = try? container.decode(UInt64.self) {
            self = .shared(id: integer)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unable to decode bit")
        }
    }
}

struct YSPort: Decodable {
    var direction: Direction
    var bits: [YSBit]

    enum Direction: Int {
        case input
        case output

        static func convert(from string: String) -> Direction? {
            switch string {
                case "input": return .input
                case "output": return .output
                default:
                    return nil
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case direction = "direction"
        case bits = "bits"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let directionString = try container.decode(String.self, forKey: .direction)
        direction = .convert(from: directionString)!
        bits = try container.decode([YSBit].self, forKey: .bits)
    }
}

struct YSCell: Decodable {
    var hideName: Bool
    var type: String
    var conns: [String: [YSBit]]

    enum CodingKeys: String, CodingKey {
        case hideName = "hide_name"
        case type = "type"
        case connections = "connections"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.hideName = try container.decode(UInt32.self, forKey: .hideName) != 0
        self.type = try container.decode(String.self, forKey: .type)
        self.conns = try container.decode([String : [YSBit]].self, forKey: .connections)
    }
}

enum YSSMCellType {
    case basicGate(type: SMLogicType, size: Int?)
    case psudoDFF(hasAsyncReset: Bool)
    case psudoBRAMTimer(length: Int)

    func isInput(name: borrowing String) -> Bool {
        switch self {
            case .basicGate(_, _):
                return name != "Y"
            case .psudoDFF(_):
                return name != "Q"
            case .psudoBRAMTimer(_):
                let regex = #/B[0-9]+DATA/#
                return name.wholeMatch(of: regex) == nil
        }
    }

    var name: String {
        switch self {
            case .basicGate(_, _):
                return "Basic Gate"
            case .psudoDFF(let hasAsyncReset):
                return hasAsyncReset ? "DFFER" : "DFFE"
            case .psudoBRAMTimer(let length):
                return "BRAM TIMER (\(length))"
        }
    }
}

struct YSNetName: Decodable {
    var hideName: Bool
    var bits: [YSBit]
    var attributes: [String: String]

    enum CodingKeys: String, CodingKey {
        case hideName = "hide_name"
        case bits = "bits"
        case attributes = "attributes"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hideName = try container.decode(UInt32.self, forKey: .hideName) != 0
        bits = try container.decode([YSBit].self, forKey: .bits)
        attributes = try container.decodeIfPresent([String: String].self, forKey: .attributes) ?? [:]
    }
}
