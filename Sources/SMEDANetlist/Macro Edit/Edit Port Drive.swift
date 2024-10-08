//
//  Edit Port Drive.swift
//  Scrap Mechanic EDA
//

func editPortDrive(
    _ mainModule: inout SMModule,
    drives: [EditPortDrive],
    invalidInputGates: inout Set<UInt64>
) throws {

    // get unique ids
    var counter: UInt64 = 0
    func getNextFreeId() -> UInt64 {
        while mainModule.gates.keys.contains(counter) {
            counter += 1
        }
        defer { counter += 1 }
        return counter
    }
    // get invert source
    var source: UInt64? = nil
    func getInvertSource() -> UInt64 {
        if let source = source, mainModule.gates[source]!.dsts.count <= SMModule.gateOutputLimit {
            return source
        }

        let id = getNextFreeId()
        mainModule.gates[id] = SMGate(type: .logic(type: .or))
        source = id
        return source!
    }
    // connect
    func connect(srcId: UInt64, dstId: UInt64) {
        mainModule.gates[srcId]!.dsts.update(with: dstId)
        mainModule.gates[dstId]!.srcs.update(with: srcId)
    }

    for drive in drives {
        guard let gateIds = mainModule.inputs[drive.dstPort.port]?.gates else {
            throw EditError.noInputPort(port: drive.dstPort.port)
        }
        for i in 0..<drive.dstPort.width {
            let index = drive.dstPort.lsb + i
            let gateId = gateIds[index]
            // make sure its not already driven
            guard mainModule.gates[gateId]!.srcs.isEmpty else {
                throw EditError.repeatSink(port: drive.dstPort.port, index: index)
            }
            // calculate state
            let mask: UInt64 = 1 << i
            let state = (mask & drive.constant) != 0
            // drive the bit if it need to be on
            if state {
                mainModule.gates[gateId]!.type = .logic(type: .nor)
                let dummy = getInvertSource()
                connect(srcId: dummy, dstId: gateId)
            } else {
                mainModule.gates[gateId]!.type = .logic(type: .or)
            }
            // remove from input list
            invalidInputGates.insert(gateId)
        }
    }
}
