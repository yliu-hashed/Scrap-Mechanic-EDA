//
//  Algebraic Purge Dangling.swift
//  Scrap Mechanic EDA
//

/// Remove gates with no output.
func algebraicPurgeDangling(
    builder: SMNetBuilder,
    intrest: Set<UInt64>,
    updated: inout Set<UInt64>
) {

    var stack: [UInt64] = []
    for gateId in intrest {
        guard !builder.inputIds.contains(gateId),
              !builder.outputIds.contains(gateId),
              let gate = builder.module.gates[gateId],
              gate.dsts.count == 0
        else { continue }
        stack.append(gateId)
    }

    while let gateId = stack.popLast() {
        guard !builder.inputIds.contains(gateId),
              let gate = builder.module.gates[gateId]
        else { continue }

        guard gate.dsts.isEmpty else {
            updated.formUnion(gate.srcs)
            continue
        }

        builder.removeGate(gateId)
        stack.append(contentsOf: gate.srcs)
    }
}
