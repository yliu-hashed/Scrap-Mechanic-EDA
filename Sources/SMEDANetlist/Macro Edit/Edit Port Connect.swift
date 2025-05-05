//
//  Edit Port Connect.swift
//  Scrap Mechanic EDA
//

func editPortConnect(
    _ mainModule: inout SMModule,
    route: EditPortRoute,
    invalidInputGates: inout Set<UInt64>
) throws {
    func connect(srcId: UInt64, dstId: UInt64) {
        mainModule.gates[srcId]!.dsts.update(with: dstId)
        mainModule.gates[dstId]!.srcs.update(with: srcId)
    }

    guard route.srcPort.width == route.dstPort.width else {
        throw EditError.widthMismatch(argument: route)
    }
    let width = route.srcPort.width
    // find output port gates
    guard let outputPortGates = mainModule.outputs[route.srcPort.port]?.gates else {
        throw EditError.noOutputPort(port: route.srcPort.port)
    }
    // find input port gates
    guard let inputPortGates = mainModule.inputs[route.dstPort.port]?.gates else {
        throw EditError.noInputPort(port: route.dstPort.port)
    }
    // route
    for i in 0..<width {
        let srcIndex = route.srcPort.lsb + i
        let dstIndex = route.dstPort.lsb + i

        let srcId = outputPortGates[srcIndex]
        let dstId = inputPortGates[dstIndex]

        guard !invalidInputGates.contains(dstId) else {
            throw EditError.repeatSink(port: route.dstPort.port, index: dstIndex)
        }
        connect(srcId: srcId, dstId: dstId)
        // invalid the port
        invalidInputGates.update(with: dstId)
    }
}
