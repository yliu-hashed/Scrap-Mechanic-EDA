//
//  Placement - Ports.swift
//  Scrap Mechanic EDA
//

import SMEDANetlist
import SMEDABlueprint

func placementPorts(
    _ module: borrowing SMModule,
    into builder: SMBlueprintBuilder,
    config: borrowing PlacementConfig,
    controllerTable: inout [UInt64: UInt64],
    occupied: inout Set<SMVector>
) throws -> Set<UInt64> {
    var portGateIds: Set<UInt64> = []
    var portLocationTable: [SMVector: PortBit] = [:]

    for surface in config.surfaces {
        for (bit, coord) in surface.ports.table {

            // get port
            let port: SMModule.Port
            let isInput: Bool
            if let p = module.inputs[bit.name] {
                port = p
                isInput = true
            } else if let p = module.outputs[bit.name] {
                port = p
                isInput = false
            } else {
                throw PlacementError.portNotFound(name: bit.name)
            }
            guard port.gates.indices.contains(bit.index) else {
                throw PlacementError.portOutOfRange(portBit: bit, min: port.gates.startIndex, max: port.gates.endIndex - 1)
            }
            let gateId = port.gates[bit.index]
            guard !portGateIds.contains(gateId) else {
                throw PlacementError.portRepeated(portBit: bit)
            }

            // get color
            let colorHex = port.colorHex ?? (isInput ? SMColor.defaultInputOdd : SMColor.defaultOutputOdd).hex

            // get device
            let device: SMInputDevice?
            if isInput {
                if let deviceString = port.device {
                    guard let dev = SMInputDevice(rawValue: deviceString) else {
                        throw PlacementError.invalidDevice(name: deviceString)
                    }
                    device = dev
                } else {
                    device = surface.defaultInputDevice ?? config.defaultInputDevice
                }
            } else {
                device = nil
            }

            // calcualte position & rotation
            let position = (
                surface.position +
                surface.directionLeft.vector * coord.h +
                surface.directionUp.vector * coord.v
            )

            if let other = portLocationTable[position] {
                throw PlacementError.portCollide(portBit: bit, other: other, position: position)
            }

            let directionFace = surface.directionUp.rotated(around: surface.directionLeft)
            let directionPoint = surface.directionUp
            let rotation = SMRotation.device(facing: directionFace, pointing: directionPoint)

            // add gate
            guard case .logic(let logicType) = module.gates[gateId]!.type else { fatalError() }
            let controllerId = builder.addGate(
                type: logicType.rawValue,
                position: position,
                rotation: rotation,
                color: .custom(hex: colorHex)
            )
            controllerTable[gateId] = controllerId
            portGateIds.insert(gateId)
            occupied.insert(position)
            portLocationTable[position] = bit

            // add input device
            if let device = device {
                let devicePosition = position + directionFace.vector
                if let other = portLocationTable[devicePosition] {
                    throw PlacementError.portCollide(portBit: bit, other: other, position: devicePosition)
                }
                let deviceId = builder.addDevice(
                    position: devicePosition,
                    rotation: rotation,
                    color: .custom(hex: colorHex),
                    device: device
                )
                builder.appendControllers([controllerId], to: deviceId)
                occupied.insert(devicePosition)
                portLocationTable[devicePosition] = bit
            }
        }
    }

    // go over all inputs, make sure all is used
    for (name, port) in module.inputs {
        for (index, gateId) in port.gates.enumerated() {
            if !portGateIds.contains(gateId) {
                throw PlacementError.inputIgnored(portBit: PortBit(name: name, index: index))
            }
        }
    }

    return portGateIds
}
