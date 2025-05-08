//
//  Placement Config Parse.swift
//  Scrap Mechanic EDA
//

import Foundation
import SMEDABlueprint
import SMEDANetlist

extension PlacementConfig.Volume: Codable {
    enum CodingKeys: CodingKey {
        case position
        case size
        case fillDirectionPriority
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.position = try container.decode(SMVector.self, forKey: .position)
        self.size = try container.decode(SMVector.self, forKey: .size)
        let arr = try container.decodeIfPresent([SMDirection].self, forKey: .fillDirectionPriority) ?? [.posZ, .posY, .posX]
        let set: Set<Int> = [1,2,3]
        guard arr.allSatisfy({set.contains(abs($0.rawValue))}) else {
            throw DecodeError.notPerp(axis: arr)
        }
        guard arr.count == 3 else {
            throw DecodeError.containsDuplicate(axis: arr)
        }
        fillDirectionPrimary = arr[0]
        fillDirectionSecondary = arr[1]
        fillDirectionTertiary = arr[2]
    }

    private enum DecodeError: Error, CustomStringConvertible {
        case notPerp(axis: [SMDirection])
        case containsDuplicate(axis: [SMDirection])

        var description: String {
            switch self {
                case .notPerp(let axis):
                    return "The specified axis \(axis) does not cover all cardinal directions."
                case .containsDuplicate(let axis):
                    return "The specified axis \(axis) contains duplicate cardinal directions."
            }
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.position, forKey: .position)
        try container.encode(self.size, forKey: .size)
        let arr = [fillDirectionPrimary, fillDirectionSecondary, fillDirectionTertiary]
        try container.encode(arr, forKey: .fillDirectionPriority)
    }
}

extension PlacementConfig.PortSurface: Codable {
    enum CodingKeys: CodingKey {
        case ports
        case position
        case directionLeft
        case directionUp
        case defaultInputDevice
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.ports = try container.decode(PortConfig.self, forKey: .ports)
        self.position = try container.decode(SMVector.self, forKey: .position)
        self.directionLeft = try container.decode(SMDirection.self, forKey: .directionLeft)
        self.directionUp = try container.decode(SMDirection.self, forKey: .directionUp)
        self.defaultInputDevice = try container.decodeIfPresent(SMInputDevice.self, forKey: .defaultInputDevice)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.ports, forKey: .ports)
        try container.encode(self.position, forKey: .position)
        try container.encode(self.directionLeft, forKey: .directionLeft)
        try container.encode(self.directionUp, forKey: .directionUp)
        try container.encode(self.defaultInputDevice, forKey: .defaultInputDevice)
    }
}

extension PlacementConfig: Codable {
    enum CodingKeys: CodingKey {
        case volumes
        case surfaces
        case facade
        case defaultInputDevice
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.volumes = try container.decode([PlacementConfig.Volume].self, forKey: .volumes)
        self.surfaces = try container.decode([PlacementConfig.PortSurface].self, forKey: .surfaces)
        self.facade = try container.decodeIfPresent(Bool.self, forKey: .facade) ?? false
        self.defaultInputDevice = try container.decodeIfPresent(SMInputDevice.self, forKey: .defaultInputDevice)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.volumes, forKey: .volumes)
        try container.encode(self.surfaces, forKey: .surfaces)
        try container.encode(self.facade, forKey: .facade)
        try container.encode(self.defaultInputDevice, forKey: .defaultInputDevice)
    }
}

extension PortConfig: Codable {
    init(from decoder: any Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var lines: [String] = []
        while !container.isAtEnd {
            let line = try container.decode(String.self)
            lines.append(line)
        }
        self = try parsePortConfig(lines: lines)
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.unkeyedContainer()
        let lines: [String] = generatePortConfigLines(for: self)
        for line in lines {
            try container.encode(line)
        }
    }
}

func fetchPlacementConfig(file: String) throws -> PlacementConfig {
    let url = URL(fileURLWithPath: file, isDirectory: false)
    let decoder = JSONDecoder()
    // read and parse config
    let data = try Data(contentsOf: url)
    return try decoder.decode(PlacementConfig.self, from: data)
}

private func parsePortConfig(lines: consuming [String]) throws -> PortConfig {
    // build table
    var table: [PortBit: PortConfig.Coordinate] = [:]
    let lines = lines.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ",") })
    for (level, line) in lines.reversed().enumerated() {
        var widthUsed: Int = 0
        for value in line.reversed() {
            let trim = value.trimmingCharacters(in: .whitespaces)
            if trim.isEmpty {
                widthUsed += 1
                continue
            }
            if let count = Int(trim), count >= 0 {
                widthUsed += count
                continue
            }
            guard let port = EditPort(argument: trim) else {
                throw PortConfigParseError.cannotParsePort(description: trim)
            }
            let width = port.width
            for i in 0..<width {
                let index = port.lsb + (port.msb >= port.lsb ? i : -i)
                let key = PortBit(name: port.port, index: index)
                guard !table.keys.contains(key) else {
                    throw PortConfigParseError.repeatedPort(portBit: key)
                }
                table[key] = PortConfig.Coordinate(h: widthUsed + i, v: level)
            }
            widthUsed += width
        }
    }

    return PortConfig(table: table)
}

private func generatePortConfigLines(for config: PortConfig) -> [String] {
    var ports: [[(h: Int, bit: PortBit)]] = []
    for (bit, pos) in config.table {
        // ensure array size
        while ports.count <= pos.v {
            ports.append([])
        }
        // insert by sorting order
        let index = ports[pos.v].firstIndex { $0.h > pos.h } ?? ports[pos.v].endIndex
        ports[pos.v].insert((h: pos.h, bit: bit), at: index)
    }

    var lines: [[String]] = []
    for portline in ports {
        var line: [String] = []
        var lastName: String? = nil
        var lastMSB: Int = 0
        var lastLSB: Int = 0
        var lastH: Int? = nil
        for (h, bit) in portline {
            if lastName == bit.name, lastH == h - 1,
               lastMSB == lastLSB || lastMSB + (lastMSB > lastLSB ? 1 : -1) == bit.index {
                line.removeLast()
                line.append("\(bit.name)[\(bit.index):\(lastLSB)]")
                lastH = h
                lastMSB = bit.index
                continue
            }
            if let lastH = lastH, lastH != h - 1 {
                line.append("\(h - lastH + 1)")
            }
            line.append("\(bit.name)[\(bit.index):\(bit.index)]")
            lastName = bit.name
            lastMSB = bit.index
            lastLSB = bit.index
            lastH = h
        }
        lines.append(line)
    }
    return lines.reversed().map { $0.reversed().joined(separator: ",") }
}

private enum PortConfigParseError: Error, CustomStringConvertible {
    case cannotParsePort(description: String)
    case repeatedPort(portBit: PortBit)

    var description: String {
        switch self {
            case .cannotParsePort(let port):
                return "Cannot parse port description \"\(port)\""
            case .repeatedPort(let portBit):
                return "Port \(portBit) is repeated"
        }
    }
}
