//
//  Algebraic Reduce XOR Negate.swift
//  Scrap Mechanic EDA
//

/// Reduce negations in the fanin of XOR gates.
func algebraicReduceXORNegate(
    builder: SMNetBuilder,
    intrest: Set<UInt64>,
    updated: inout Set<UInt64>
) {
    var working: Set<UInt64> = []

    // find potential XOR gates
    for gateId in intrest {
        guard let gate = builder.module.gates[gateId],
              case .logic(let logicType) = gate.type
        else { continue }
        if logicType.isInverter {
            working.formUnion(gate.dsts)
        }
        if logicType.sourceAggrigationType == .logicalParity {
            working.insert(gateId)
        }
    }

    while let gateId = working.popFirst() {
        let gate = builder.module.gates[gateId]!
        // skips over non-XOR gates
        guard case .logic(let logicType) = gate.type,
              logicType.sourceAggrigationType == .logicalParity
        else { continue }

        // enumerate reducible negations
        var reducibles: [UInt64: SMLogicType] = [:]
        for srcId in gate.srcs {
            let src = builder.module.gates[srcId]!
            guard src.isCombinational,
                  !src.srcs.isEmpty,
                  src.dsts.count == 1,
                  case .logic(let logicType) = src.type,
                  logicType.isInverter,
                  !builder.inputIds.contains(srcId)
            else { continue }
            reducibles[srcId] = logicType
        }

        // reduce every pair
        while reducibles.count > 1 {
            let (srcId1, type1) = reducibles.popFirst()!
            let (srcId2, type2) = reducibles.popFirst()!
            builder.changeGateType(of: srcId1, to: .logic(type: type1.negatedGate))
            builder.changeGateType(of: srcId2, to: .logic(type: type2.negatedGate))
            updated.insert(srcId1)
            updated.insert(srcId2)
        }

        // reduce last negation by flipping XOR polarity if possible
        if let (srcId, type) = reducibles.popFirst(), gate.isCombinational {
            builder.changeGateType(of: srcId, to: .logic(type: type.negatedGate))
            builder.changeGateType(of: gateId, to: .logic(type: logicType.negatedGate))
            updated.insert(srcId)
            updated.insert(gateId)
            // self became a negate
            if logicType == .xor {
                working.formUnion(gate.dsts)
            }
        }
    }
}

