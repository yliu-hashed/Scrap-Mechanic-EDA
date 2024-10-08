//
//  Edit Port Connect.swift
//  Scrap Mechanic EDA
//

func editPortConnect(
    _ mainModule: inout SMModule,
    portRouteTable: [EditPortRoute],
    invalidInputGates: inout Set<UInt64>
) throws {

    func connect(srcId: UInt64, dstId: UInt64) {
        mainModule.gates[srcId]!.dsts.update(with: dstId)
        mainModule.gates[dstId]!.srcs.update(with: srcId)
    }

    for portRoute in portRouteTable {
        guard portRoute.srcPort.width == portRoute.dstPort.width else {
            throw EditError.widthMismatch(argument: portRoute)
        }
        let width = portRoute.srcPort.width
        // find output port gates
        guard let outputPortGates = mainModule.outputs[portRoute.srcPort.port]?.gates else {
            throw EditError.noOutputPort(port: portRoute.srcPort.port)
        }
        // find input port gates
        guard let inputPortGates = mainModule.inputs[portRoute.dstPort.port]?.gates else {
            throw EditError.noInputPort(port: portRoute.dstPort.port)
        }
        // route
        for i in 0..<width {
            let srcIndex = portRoute.srcPort.lsb + i
            let dstIndex = portRoute.dstPort.lsb + i

            let srcId = outputPortGates[srcIndex]
            let dstId = inputPortGates[dstIndex]

            guard !invalidInputGates.contains(dstId) else {
                throw EditError.repeatSink(port: portRoute.dstPort.port, index: dstIndex)
            }
            connect(srcId: srcId, dstId: dstId)
            // invalid the port
            invalidInputGates.update(with: dstId)
        }
    }
}
