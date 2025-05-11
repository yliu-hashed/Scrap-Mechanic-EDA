//
//  Placement Config Report.swift
//  Scrap Mechanic EDA
//

import SMEDAResult

func generateReportForConfig(for config: borrowing PortConfig) -> PlacementReport.PortSurface {
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

    var lines: [[PlacementReport.PortSegment]] = []
    for portline in ports {
        var segments: [PlacementReport.PortSegment] = []
        var lastName: String? = nil
        var lastMSB: Int = 0
        var lastLSB: Int = 0
        var lastH: Int = -1
        for (h, bit) in portline {
            if lastName == bit.name, lastH == h - 1,
               lastMSB == lastLSB || lastMSB + (lastMSB > lastLSB ? 1 : -1) == bit.index {
                let lastSegment = segments.removeLast()
                let segment = PlacementReport.PortSegment(
                    name: bit.name,
                    lsb: lastLSB,
                    msb: bit.index,
                    offset: lastSegment.offset
                )
                segments.append(segment)
                lastH = h
                lastMSB = bit.index
                continue
            }
            let segment = PlacementReport.PortSegment(
                name: bit.name,
                lsb: bit.index,
                msb: bit.index,
                offset: h
            )
            segments.append(segment)
            lastName = bit.name
            lastMSB = bit.index
            lastLSB = bit.index
            lastH = h
        }
        lines.append(segments)
    }
    return lines
}
