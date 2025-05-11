//
//  Placement.swift
//  Scrap Mechanic EDA
//

import SMEDANetlist
import SMEDABlueprint
import SMEDAResult

func place(
    _ module: borrowing SMModule,
    config: borrowing PlacementConfig,
    report: inout PlacementReport
) throws -> SMBlueprint {
    let builder = SMBlueprintBuilder()
    // place all ports
    var controllerTable: [UInt64: UInt64] = [:]
    var occupied: Set<SMVector> = []

    // place ports
    let portGateIds = try placementPorts(
        module,
        into: builder,
        config: config,
        controllerTable: &controllerTable,
        occupied: &occupied
    )

    // enumerate out all the spaces that would be used by ordinary gates and timers
    var space = try placementEnumerateSpace(
        module,
        config: config,
        occupied: &occupied,
        portGateIds: portGateIds
    )

    // helper function to get timer space
    func allocateSpaceForTimer() throws -> (pos: SMVector, rot: SMRotation) {
        var pos = space.randomElement()!
        while true {
            guard let dir = SMDirection.allCases.first(where: { space.contains(pos + $0.vector) }) else {
                pos = space.randomElement()!
                continue
            }
            space.remove(pos)
            space.remove(pos + dir.vector)
            return (pos, .timer(pointing: dir))
        }
    }

    // place all timers
    for (gateId, gate) in module.gates {
        guard case .timer(let delay) = gate.type else { continue }
        let (pos, rot) = try allocateSpaceForTimer()
        let controllerId = builder.addTimer(
            delay: delay,
            position: pos,
            rotation: rot,
            color: .defaultBodyGates
        )
        controllerTable[gateId] = controllerId
    }

    // place all ordinary gates
    for (gateId, gate) in module.gates {
        guard !portGateIds.contains(gateId) else { continue }
        guard case .logic(let type) = gate.type else { continue }
        let pos = space.removeFirst()
        // enable facade if all adjacent positions are covered (or explicitly disabled)
        let noFacade = !config.facade || SMDirection.allCases.allSatisfy {
            occupied.contains(pos + $0.vector)
        }
        let rot: SMRotation = noFacade ? .zero : .random()
        let controllerId = builder.addGate(
            type: type.rawValue,
            position: pos,
            rotation: rot,
            color: .defaultBodyGates
        )
        controllerTable[gateId] = controllerId
    }

    assert(space.isEmpty)

    // connect all gates together
    for (gateId, gate) in module.gates {
        let targetController = controllerTable[gateId]!
        for sourceGateId in gate.srcs {
            let sourceController = controllerTable[sourceGateId]!
            builder.appendControllers([targetController], to: sourceController)
        }
    }

    // report placed surfaces and size info
    for surface in config.surfaces {
        let table = generateReportForConfig(for: surface.ports)
        let baseName = surface.name ?? "Surface"
        var index: Int? = nil
        while true {
            let name = if let index { "\(baseName) \(index)" } else { baseName }
            if !report.surfaces.keys.contains(name) { break }
            index = (index ?? 0) + 1
        }
        let name = if let index { "\(baseName) \(index)" } else { baseName }
        report.surfaces[name] = table
    }

    var maxX: Int = 0
    var minX: Int = 0
    var maxY: Int = 0
    var minY: Int = 0
    var maxZ: Int = 0
    var minZ: Int = 0
    for pos in occupied {
        maxX = max(maxX, pos.x)
        minX = min(minX, pos.x)
        maxY = max(maxY, pos.y)
        minY = min(minY, pos.y)
        maxZ = max(maxZ, pos.z)
        minZ = min(minZ, pos.z)
    }
    report.depth  = maxX - minX + 1
    report.width  = maxY - minY + 1
    report.height = maxZ - minZ + 1

    return SMBlueprint(bodies: [builder.blueprintBody])
}

enum PlacementError: Error, CustomStringConvertible {
    case portNotFound(name: String)
    case portOutOfRange(portBit: PortBit, min: Int, max: Int)
    case invalidDevice(name: String)
    case portNotLogic(portBit: PortBit)
    case portCollide(portBit: PortBit, other: PortBit, position: SMVector)
    case portRepeated(portBit: PortBit)
    case inputIgnored(portBit: PortBit)
    case spaceNotEnouph(current: Int)

    var description: String {
        switch self {
            case .portNotFound(let name):
                return "Port \"\(name)\" does not exist"
            case .portOutOfRange(let portBit, let min, let max):
                return "Port \"\(portBit)\" is out of the valid range of [\(min):\(max)]"
            case .invalidDevice(let name):
                return "Cannot recognize specified device \"\(name)\""
            case .portNotLogic(let portBit):
                return "Port \"\(portBit)\" is not a logic gate"
            case .portCollide(let portBit, let other, let position):
                return "Port \"\(portBit)\" collides with port \"\(other)\" at position \(position)"
            case .portRepeated(let portBit):
                return "Port \"\(portBit)\" is repeated during placement"
            case .inputIgnored(let portBit):
                return "Input port \"\(portBit)\" never used in placement"
            case .spaceNotEnouph(let current):
                return "The give volumes (\(current) blocks) are not enouph to fit the design"
        }
    }
}
