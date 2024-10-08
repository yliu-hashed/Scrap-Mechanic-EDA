//
//  Edit Port Share.swift
//  Scrap Mechanic EDA
//

func editPortShare(
    _ mainModule: inout SMModule,
    portRouteTable: [EditPortRoute],
    invalidInputGates: inout Set<UInt64>
) throws {

    func share(_ srcId: UInt64, with dstId: UInt64) {
        mainModule.gates[srcId]!.dsts.update(with: dstId)
        mainModule.gates[dstId]!.srcs.update(with: srcId)
    }

    for portRoute in portRouteTable {
        guard portRoute.srcPort.width == portRoute.dstPort.width else {
            throw EditError.widthMismatch(argument: portRoute)
        }
        let width = portRoute.srcPort.width
        // find output port gates
        guard let srcPort = mainModule.inputs[portRoute.srcPort.port] else {
            throw EditError.noOutputPort(port: portRoute.srcPort.port)
        }
        // find input port gates
        guard let dstPort = mainModule.inputs[portRoute.dstPort.port] else {
            throw EditError.noInputPort(port: portRoute.dstPort.port)
        }

        let isClockPort = srcPort.isClock && dstPort.isClock
        mainModule.inputs[portRoute.srcPort.port]!.isClock = isClockPort

        // route
        for i in 0..<width {
            let srcIndex = portRoute.srcPort.lsb + i
            let dstIndex = portRoute.dstPort.lsb + i

            let srcId = srcPort.gates[srcIndex]
            let dstId = dstPort.gates[dstIndex]

            guard !invalidInputGates.contains(dstId) else {
                throw EditError.repeatSink(port: portRoute.dstPort.port, index: dstIndex)
            }

            share(srcId, with: dstId)
            // invalid the port
            invalidInputGates.update(with: dstId)
        }
    }
}
