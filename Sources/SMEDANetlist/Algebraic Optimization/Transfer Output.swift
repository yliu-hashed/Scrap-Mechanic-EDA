//
//  Transfer Output.swift
//  Scrap Mechanic EDA
//

func transferOutput(
    builder: SMNetBuilder,
    from gate2Id: UInt64,
    to gate1Id: UInt64,
    pull: (UInt64)->Void
) -> Bool {
    let gate1 = builder.module.gates[gate1Id]!
    let gate2 = builder.module.gates[gate2Id]!

    var dsts = gate1.dsts
    for dstId in gate2.dsts {
        let dst = builder.module.gates[dstId]!
        guard case .logic(let type) = dst.type else { continue }
        // if both sources goes into an XOR or XNOR,
        // then remove the connection (double negation)
        if dsts.contains(dstId), type.sourceAggrigationType == .logicalParity {
            dsts.remove(dstId)
            // prevent XNOR gate from becomming a constant 1 but having zero inputs
            if dst.srcs.count == 2, type.isInverter {
                pull(dstId)
            }
        } else {
            dsts.insert(dstId)
        }
    }

    // skip if too big
    guard dsts.count <= SMModule.gateOutputLimit else { return false }

    builder.disconnect(gate2Id, to: gate2.dsts)
    // additions
    for dstId in dsts where !gate1.dsts.contains(dstId) {
        builder.connect(gate1Id, to: dstId)
    }
    // removals
    for dstId in gate1.dsts where !dsts.contains(dstId) {
        builder.disconnect(gate1Id, to: dstId)
    }
    return true
}
