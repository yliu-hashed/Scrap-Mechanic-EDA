//
//  Peephole Siblings.swift
//  Scrap Mechanic EDA
//

/*-----BEFORE----X---------------X-----AFTER----*/
/*      ...      |      ...      |      ...     */
/*      /  \     |      /  \     |       |      */
/*  gate  gate2  |   gate  gate2 |     gate     */
/*    |     |    |    |  \       |     /   \    */
/*   ...   ...   |   ... ...     |  ...    ...  */
/*---------------X---------------X--------------*/

/// Simplify the provided module by reducing identical sibling. This pass does not modify timing.
/// - Parameters:
///   - builder: the module to optimize
///   - keeping: a set of nodes to not remove, usually output nodes
///   - verbose: print reduction stats
/// - Returns: whether any change is done at all
@discardableResult
public func peepoptJoinIdenticalSibings(builder: SMNetBuilder, keeping: Set<UInt64>) -> Bool {
    var changeCount: Int = 0

    // Obtain a non mutating list of all gate ids
    let targetGates: Set<UInt64> = Set(builder.module.gates.keys).subtracting(keeping)

    var gateInputHashSet: Set<Int> = []
    var hashesOfIntrest: Set<Int> = []
    var gatesOfIntrest: Set<UInt64> = []
    for gateId in targetGates {
        let sourceHash = builder.module.gates[gateId]!.srcs.hashValue
        if hashesOfIntrest.contains(sourceHash) {
            continue
        }
        if gateInputHashSet.contains(sourceHash) {
            hashesOfIntrest.update(with: sourceHash)
            gatesOfIntrest.update(with: gateId)
        } else {
            gateInputHashSet.update(with: sourceHash)
        }
    }

    for gateId in targetGates {
        let sourceHash = builder.module.gates[gateId]!.srcs.hashValue
        if hashesOfIntrest.contains(sourceHash) {
            gatesOfIntrest.update(with: gateId)
        }
    }

    // loop through all gates once
    for gateId in gatesOfIntrest {
        guard builder.module.gates.keys.contains(gateId) else { continue }

        // find sibling
        for gateId2 in gatesOfIntrest where gateId2 != gateId {
            let gate = builder.module.gates[gateId]!
            guard let gate2 = builder.module.gates[gateId2],
                  case .logic(let gateType) = gate.type,
                  case .logic(let gate2Type) = gate2.type
            else { continue }
            // match any gates that have the same source and type of the first gate
            // and optimize out this gate
            if gateType.isLogicallyEquiv(to: gate2Type, inputCount: gate.srcs.count),
               gate2.srcs == gate.srcs {
                let transfer = gate2.dsts
                let newCount = gate.dsts.union(gate2.dsts)
                guard newCount.count <= SMModule.gateOutputLimit else { continue }
                // transfer source to first gate
                builder.transferPortals(from: gateId2, to: gateId)
                builder.removeGate(gateId2)
                builder.connect(gateId, to: transfer)
                changeCount += 1
            }
        }
    }

    return changeCount > 0
}
