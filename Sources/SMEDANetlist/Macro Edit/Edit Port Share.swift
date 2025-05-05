//
//  Edit Port Share.swift
//  Scrap Mechanic EDA
//

func editPortShare(
    _ mainModule: inout SMModule,
    route: EditPortRoute,
    invalidInputGates: inout Set<UInt64>
) throws {

    func share(_ srcId: UInt64, with dstId: UInt64) {
        mainModule.gates[srcId]!.dsts.update(with: dstId)
        mainModule.gates[dstId]!.srcs.update(with: srcId)
    }

    guard route.srcPort.width == route.dstPort.width else {
        throw EditError.widthMismatch(argument: route)
    }
    let width = route.srcPort.width
    // find output port gates
    guard let srcPort = mainModule.inputs[route.srcPort.port] else {
        throw EditError.noOutputPort(port: route.srcPort.port)
    }
    // find input port gates
    guard let dstPort = mainModule.inputs[route.dstPort.port] else {
        throw EditError.noInputPort(port: route.dstPort.port)
    }

    let isClockPort = srcPort.isClock && dstPort.isClock
    mainModule.inputs[route.srcPort.port]!.isClock = isClockPort

    // route
    for i in 0..<width {
        let srcIndex = route.srcPort.lsb + i
        let dstIndex = route.dstPort.lsb + i

        let srcId = srcPort.gates[srcIndex]
        let dstId = dstPort.gates[dstIndex]

        guard !invalidInputGates.contains(dstId) else {
            throw EditError.repeatSink(port: route.dstPort.port, index: dstIndex)
        }

        share(srcId, with: dstId)
        // invalid the port
        invalidInputGates.update(with: dstId)
    }
}
