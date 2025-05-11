//
//  Auto Plan.swift
//  Scrap Mechanic EDA
//

import SMEDANetlist
import SMEDABlueprint

func autoPlan(
    for module: borrowing SMModule,
    depth: Int? = nil,
    width: Int? = nil,
    device: SMInputDevice? = nil,
    noFacade: Bool,
    portDoubleSided: Bool,
    packPort: Bool,
    sinkPort: Bool
) -> PlacementConfig {

    // survey the design, get the number of logics and timer counts
    var timerCount: Int = 0
    var logicCount: Int = 0
    var maxPortWidth: Int = 0
    for gate in module.gates.values {
        if gate.type.group == .timer {
            timerCount += 1
        } else {
            logicCount += 1
        }
    }
    for port in module.inputs.values {
        let count = port.gates.count
        if !sinkPort { logicCount -= count }
        maxPortWidth = max(count, maxPortWidth)
    }
    for port in module.outputs.values {
        let count = port.gates.count
        if !sinkPort { logicCount -= count }
        maxPortWidth = max(count, maxPortWidth)
    }

    if let depth = depth, timerCount + logicCount > depth {
        print("WARNING: Depth argument is too large. The gate body will be detached from the ports.")
    }

    // calculate width wrapping
    let planWidth: Int
    if let width = width {
        planWidth = width
    } else {
        let maxSensableWidth = 16
        planWidth = min(maxPortWidth, maxSensableWidth)
    }

    // layout inputs
    let portHeight: Int
    let surfaceFront: PortConfig
    let surfaceBack: PortConfig?
    if portDoubleSided {
        let (layoutFront, heightFront) = layoutPorts(ports: module.inputs , width: planWidth, packed: packPort)
        let (layoutBack , heightBack ) = layoutPorts(ports: module.outputs, width: planWidth, packed: packPort)
        surfaceFront = layoutFront
        surfaceBack = layoutBack
        portHeight = max(heightFront, heightBack)
    } else {
        let merged = module.inputs.merging(module.outputs) { $1 }
        let (layout, height) = layoutPorts(ports: merged, width: planWidth, packed: packPort)
        surfaceFront = layout
        surfaceBack = nil
        portHeight = height
    }

    // calcualte dimensions
    let planDepth: Int
    if let depth = depth {
        planDepth = depth
    } else {
        let counts = logicCount + timerCount * 2
        let planeSize = max(portHeight, 1) * planWidth
        planDepth = min(max(counts / planeSize, 1), 32)
    }

    // create config
    let volume = PlacementConfig.Volume(
        position: .zero,
        size: SMVector(x: planDepth, y: planWidth, z: 1000000),
        fillDirectionPrimary: .posZ,
        fillDirectionSecondary: .posY,
        fillDirectionTertiary: .posX
    )

    var surfaces: [PlacementConfig.PortSurface] = []
    surfaces.append(PlacementConfig.PortSurface(
        name: portDoubleSided ? "Inputs" : "Ports",
        ports: surfaceFront,
        position: SMVector(x: sinkPort ? 0 : -1),
        directionLeft: .posY,
        directionUp: .posZ
    ))

    if let surfaceBack = surfaceBack {
        surfaces.append(PlacementConfig.PortSurface(
            name: "Outputs",
            ports: surfaceBack,
            position: SMVector(x: sinkPort ? planDepth - 1 : planDepth),
            directionLeft: .posY,
            directionUp: .posZ
        ).flipped(width: planWidth))
    }

    return PlacementConfig(
        volumes: [volume],
        surfaces: surfaces,
        facade: !noFacade,
        defaultInputDevice: device
    )
}

private extension PlacementConfig.PortSurface {
    func flipped(width: Int) -> PlacementConfig.PortSurface {
        let pos = self.position + directionLeft.vector * (width - 1)

        var table: [PortBit: PortConfig.Coordinate] = [:]
        table.reserveCapacity(ports.table.count)

        for (bit, port) in ports.table {
            table[bit] = PortConfig.Coordinate(h: width - port.h - 1, v: port.v)
        }

        return PlacementConfig.PortSurface(
            name: name,
            ports: PortConfig(table: table),
            position: pos,
            directionLeft: directionLeft.opposite,
            directionUp: directionUp,
            defaultInputDevice: defaultInputDevice
        )
    }
}
