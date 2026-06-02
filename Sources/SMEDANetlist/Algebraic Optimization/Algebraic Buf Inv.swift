//
//  Algebraic Buf Inv.swift
//  Scrap Mechanic EDA
//

/// Sink inverters into their fanin gate.
func algebraicReduceBuffersAndInverters(
    builder: SMNetBuilder,
    intrest: Set<UInt64>,
    updated: inout Set<UInt64>
) {

    var working: Set<UInt64> = []

    for gateId in intrest {
        guard let gate = builder.module.gates[gateId],
              !builder.outputIds.contains(gateId),
              gate.srcs.count == 1,
              gate.isCombinational
        else { continue }
        working.insert(gateId)
    }

    let lowDriver = builder.defered {
        return builder.addLogic(type: .or)
    }

    while let gateId = working.popFirst() {
        guard let gate = builder.module.gates[gateId],
              !builder.outputIds.contains(gateId),
              gate.srcs.count == 1,
              gate.isCombinational
        else { continue }

        let dsts = gate.dsts
        let srcId = gate.srcs.first!
        let src = builder.module.gates[srcId]!

        if case .logic(let logicType) = gate.type, logicType.isInverter { // reduce inverter
            guard case .logic(let sourceType) = src.type,
                  !builder.inputIds.contains(srcId),
                  src.dsts.count == 1,
                  !src.srcs.isEmpty, // cannot sink inverter into 0 input gate (it always outputs low)
                  gate.isCombinational
            else { continue }

            builder.changeGateType(of: srcId, to: .logic(type: sourceType.negatedGate))

            builder.connect(srcId, to: dsts)
            builder.removeGate(gateId)

            updated.remove(gateId)
            updated.insert(srcId)
            updated.formUnion(dsts)

            if src.srcs.count == 1 {
                working.insert(srcId)
                updated.formUnion(src.srcs)
            }

        } else {
            // ensure a transfer will not violate output limit
            let success = transferOutput(
                builder: builder,
                from: gateId,
                to: srcId
            ) { pullId in
                builder.changeGateType(of: pullId, to: .logic(type: .nor))
                builder.connect(lowDriver.use(), to: pullId)
            }

            guard success else { continue }

            builder.removeGate(gateId)

            updated.remove(gateId)
            updated.insert(srcId)
            updated.formUnion(dsts)
        }
    }
}
