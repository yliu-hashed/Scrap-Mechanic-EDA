//
//  Peephole Buf Inv.swift
//  Scrap Mechanic EDA
//

/*-------------------------------*/
/*     Reduce Buffer/Inverter    */
/*-----BEFORE----X-----AFTER-----*/
/*      ...      |      ...      */
/*       |       |       |       */
/*    source     |    source     */
/*       |       |       |       */
/*     gate      |       |       */
/*       |       |       |       */
/*      ...      |      ...      */
/*---------------X---------------*/
/*      Transfer (with deps)     */
/*-----BEFORE----X-----AFTER-----*/
/*      ...      |      ...      */
/*       |       |     /   \     */
/*    source     |  source  dupe */
/*      /  \     |    |      |   */
/*    gate  dep  |   ...    dep  */
/*     |         |               */
/*    ...        |               */
/*---------------X---------------*/

@discardableResult
public func peepoptReduceBuffers(builder: SMNetBuilder, keeping: Set<UInt64>) -> Bool {
    var removalCount: Int = 0

    let gatesOfIntrest: Set<UInt64> = Set(builder.module.gates.keys).subtracting(keeping)

    for gateId in gatesOfIntrest {
        guard let gate = builder.module.gates[gateId],
              case .logic(let gateType) = gate.type,
              !gateType.isInverter,
              gate.srcs.count == 1,
              !builder.module.sequentialNodes.contains(gateId)
        else { continue }

        let transfer = gate.dsts
        let srcId = gate.srcs.first!

        guard builder.module.gates[srcId]!.dsts
            .subtracting([gateId]).union(transfer).count <= SMModule.gateOutputLimit
        else { continue }

        builder.removeGate(gateId)
        builder.connect(srcId, to: transfer)

        removalCount += 1
    }

    return removalCount > 1
}

@discardableResult
public func peepoptReduceInverters(builder: SMNetBuilder, keeping: Set<UInt64>) -> Bool {
    var removalCount: Int = 0

    let gatesOfIntrest: Set<UInt64> = Set(builder.module.gates.keys).subtracting(keeping)

    for gateId in gatesOfIntrest {
        guard let gate = builder.module.gates[gateId],
              case .logic(let gateType) = gate.type,
              gateType.isInverter,
              gate.srcs.count == 1,
              !builder.module.sequentialNodes.contains(gateId)
        else { continue }

        let srcId = gate.srcs.first!

        guard let source = builder.module.gates[srcId],
              case .logic(let sourceType) = source.type,
              !keeping.contains(srcId),
              source.dsts.count == 1,
              !source.srcs.isEmpty, // cannot sink inverter into 0 input gate (it always outputs low)
              !builder.module.sequentialNodes.contains(srcId)
        else { continue }

        let transfer = gate.dsts

        builder.removeGate(gateId)
        builder.connect(srcId, to: transfer)
        builder.changeGateType(of: srcId, to: .logic(type: sourceType.negatedGate))

        removalCount += 1
    }

    return removalCount > 1
}
