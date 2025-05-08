//
//  Placement Config.swift
//  Scrap Mechanic EDA
//

import SMEDABlueprint
import SMEDANetlist

struct PlacementConfig {
    struct Volume {
        var position: SMVector
        var size: SMVector
        var fillDirectionPrimary: SMDirection
        var fillDirectionSecondary: SMDirection
        var fillDirectionTertiary: SMDirection
    }

    struct PortSurface {
        var ports: PortConfig
        var position: SMVector
        var directionLeft: SMDirection
        var directionUp: SMDirection
        var defaultInputDevice: SMInputDevice? = nil
    }

    var volumes: [Volume]
    var surfaces: [PortSurface]
    var facade: Bool
    var defaultInputDevice: SMInputDevice? = nil
}

struct PortBit: Hashable, Equatable, CustomStringConvertible {
    var name: String
    var index: Int

    var description: String {
        return "\(name)[\(index)]"
    }
}

struct PortConfig {
    struct Coordinate {
        let h: Int
        let v: Int
    }

    let table: [PortBit: Coordinate]
    let minWidth: Int
    let minHeight: Int

    init(table: consuming [PortBit : Coordinate]) {
        self.table = table
        var maxV: Int = 0
        var maxH: Int = 0
        for (_, coord) in self.table {
            maxV = max(maxV, coord.v)
            maxH = max(maxH, coord.h)
        }
        self.minWidth  = maxH
        self.minHeight = maxV
    }
}
