//
//  Auto Plan Ports.swift
//  Scrap Mechanic EDA
//

import SMEDANetlist

func layoutPorts(ports: borrowing [String: SMModule.Port], width: Int, packed: Bool) -> (config: PortConfig, height: Int) {
    if packed {
        return layoutPortsPacked(ports: ports, width: width)
    } else {
        return layoutPortsOrdered(ports: ports, width: width)
    }
}

private func layoutPortsPacked(ports: borrowing [String: SMModule.Port], width: Int) -> (config: PortConfig, height: Int) {
    var table: [PortBit: PortConfig.Coordinate] = [:]

    var layers: [Int] = []
    let ranked = ports.lazy.sorted { (lhs, rhs) in
        let lhsCount = lhs.value.gates.count
        let rhsCount = rhs.value.gates.count
        if lhsCount != rhsCount {
            return lhsCount > rhsCount
        } else {
            return lhs.key > rhs.key
        }
    }

    for (name, port) in ranked {
        let portSize = port.gates.count
        // if can fit, add
        let fitLayer = layers.firstIndex { width - $0 >= portSize }
        if let fitLayer = fitLayer {
            let offset = layers[fitLayer]
            for i in 0..<portSize {
                let coord = PortConfig.Coordinate(h: offset + i, v: fitLayer)
                table[PortBit(name: name, index: i)] = coord
            }
            layers[fitLayer] += portSize
            continue
        }
        // if cannot fit, add a new layer
        var bitsPlaced = 0
        while bitsPlaced < portSize {
            let bitsThisLayer = min(width, portSize - bitsPlaced)
            layers.append(bitsThisLayer)
            for i in 0..<bitsThisLayer {
                let coord = PortConfig.Coordinate(h: i, v: layers.count - 1)
                table[PortBit(name: name, index: bitsPlaced + i)] = coord
            }
            bitsPlaced += bitsThisLayer
        }
    }

    return (PortConfig(table: table), layers.count)
}

private func layoutPortsOrdered(ports: borrowing [String: SMModule.Port], width: Int) -> (config: PortConfig, height: Int) {
    var table: [PortBit: PortConfig.Coordinate] = [:]

    var layers: [Int] = []
    let ordered = ports.lazy.sorted { $0.key > $1.key }
    for (name, port) in ordered {
        let portSize = port.gates.count
        // if can fit, add
        if let lastLayerSize = layers.last, width - lastLayerSize >= portSize {
            for i in 0..<portSize {
                let coord = PortConfig.Coordinate(h: lastLayerSize + i, v: layers.count - 1)
                table[PortBit(name: name, index: i)] = coord
            }
            layers[layers.count - 1] += portSize
            continue
        }
        // if cannot fit, add a new layer
        var bitsPlaced = 0
        while bitsPlaced < portSize {
            let bitsThisLayer = min(width, portSize - bitsPlaced)
            layers.append(bitsThisLayer)
            for i in 0..<bitsThisLayer {
                let coord = PortConfig.Coordinate(h: i, v: layers.count - 1)
                table[PortBit(name: name, index: bitsPlaced + i)] = coord
            }
            bitsPlaced += bitsThisLayer
        }
    }

    return (PortConfig(table: table), layers.count)
}
