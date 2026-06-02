//
//  Algebraic Merge Identical.swift
//  Scrap Mechanic EDA
//

/// Merge gate with the same set of inputs.
func algebraicMergeIdentical(
    builder: SMNetBuilder,
    intrest: Set<UInt64>,
    updated: inout Set<UInt64>
) {
    var hashTable: [Int: [UInt64]] = [:]

    for gateId in intrest {
        guard !builder.inputIds.contains(gateId),
              !builder.outputIds.contains(gateId),
              let gate = builder.module.gates[gateId],
              case .logic(let logicType) = gate.type
        else { continue }

        let hash = gate.srcs.hashValue ^ logicType.hashValue
        if hashTable.keys.contains(hash) {
            hashTable[hash]!.append(gateId)
        } else {
            hashTable[hash] = [gateId]
        }
    }

    let lowDriver = builder.defered {
        return builder.addLogic(type: .or)
    }

    for group in hashTable.values {
        for (index1, gateId1) in group.enumerated() {
            guard builder.module.gates.keys.contains(gateId1) else { continue }
            // find identical
            for index2 in 0..<index1 {
                let gateId2 = group[index2]
                let gate1 = builder.module.gates[gateId1]!

                guard let gate2 = builder.module.gates[gateId2],
                      case .logic(let gate1Type) = gate1.type,
                      case .logic(let gate2Type) = gate2.type,
                      gate1.domain == gate2.domain
                else { continue }

                // match any gates that have the same source and type of the first gate
                // and optimize out this gate
                guard gate1Type.isLogicallyEquiv(to: gate2Type, inputCount: gate1.srcs.count),
                      gate1.srcs == gate2.srcs
                else { continue }

                let success = transferOutput(
                    builder: builder,
                    from: gateId2,
                    to: gateId1
                ) { pullId in
                    builder.changeGateType(of: pullId, to: .logic(type: .nor))
                    builder.connect(lowDriver.use(), to: pullId)
                }

                guard success else { continue }

                // update
                updated.formUnion(gate1.dsts)
                updated.formUnion(gate2.dsts)
                updated.formUnion(gate1.srcs)

                // transfer source to first gate
                builder.transferPortals(from: gateId2, to: gateId1)
                builder.removeGate(gateId2)
                updated.remove(gateId2)
                updated.insert(gateId1)
            }
        }
    }
}
