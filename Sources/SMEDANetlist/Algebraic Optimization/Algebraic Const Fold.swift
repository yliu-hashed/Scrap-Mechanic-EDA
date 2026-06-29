//
//  Algebraic Const Fold.swift
//  Scrap Mechanic EDA
//

func algebraicConstFold(
    builder: SMNetBuilder,
    updated: inout Set<UInt64>
) {

    var localUpdated: Set<UInt64> = []

    // enumerate all gates that are considered constant
    let info = identifyConstantNodes(
        builder: builder
    )

    // simplify all gates that uses at least one constant
    let redrives = foldConstantDrives(
        builder: builder,
        info: info,
        updated: &localUpdated
    )

    // optimize constant drives
    optimizeDrives(
        builder: builder,
        info: info,
        redrives: redrives,
        updated: &localUpdated
    )

    updated.formUnion(localUpdated)

    // purge unused stuff that may be dangled as result of removing constants
    algebraicPurgeDangling(
        builder: builder,
        intrest: localUpdated,
        updated: &updated
    )
}

private func optimizeDrives(
    builder: SMNetBuilder,
    info: ConstantInfo,
    redrives: [UInt64: Bool],
    updated: inout Set<UInt64>
) {
    struct Immidiate {
        var gateId: UInt64
        var usage: Int
    }

    // sort all usable existing immidiates by their usage
    var immidiates: [Immidiate] = []
    for gateId in info.immidiates {
        let gate = builder.module.gates[gateId]!
        let usage = gate.dsts.count
        guard usage < SMModule.gateOutputLimit else { continue }
        immidiates.append(Immidiate(gateId: gateId, usage: usage))
    }
    immidiates.sort(by: { $0.usage < $1.usage })

    // sort all usable existing inverter of immidiates by their usage
    var invertedImmidiates: [Immidiate] = []
    for gateId in info.invertedImmidiates {
        let gate = builder.module.gates[gateId]!
        let usage = gate.dsts.count
        guard usage < SMModule.gateOutputLimit else { continue }
        invertedImmidiates.append(Immidiate(gateId: gateId, usage: usage))
    }
    invertedImmidiates.sort(by: { $0.usage < $1.usage })

    /// Helper function to obtain a constant false drive
    func useNormal() -> UInt64 {
        guard let last = immidiates.last else {
            let gateId = builder.addGate(type: .logic(type: .or))
            immidiates.append(Immidiate(gateId: gateId, usage: 1))
            return gateId
        }
        immidiates[immidiates.endIndex - 1].usage += 1
        if last.usage == SMModule.gateOutputLimit {
            immidiates.removeLast()
        }
        return last.gateId
    }

    /// Helper function to obtain a constant true drive
    func useInverted() -> UInt64 {
        guard let last = invertedImmidiates.last else {
            let gateId = builder.addGate(type: .logic(type: .nor))
            builder.connect(useNormal(), to: gateId)
            invertedImmidiates.append(Immidiate(gateId: gateId, usage: 1))
            return gateId
        }
        invertedImmidiates[invertedImmidiates.endIndex - 1].usage += 1
        if last.usage == SMModule.gateOutputLimit {
            invertedImmidiates.removeLast()
        }
        return last.gateId
    }

    // drive everything that needs to be re-driven
    for (gateId, value) in redrives {
        let srcId = value ? useInverted() : useNormal()
        builder.connect(srcId, to: gateId)
        updated.insert(srcId)
        updated.insert(gateId)
    }
}

private struct ConstantInfo {
    /// Gates that are detected to produce a constant value.
    var constants: [UInt64: Bool]
    /// Gates that have no input and thus produce a constant false value.
    var immidiates: Set<UInt64>
    /// Gates that have immidiates as the only input, and thus produces a constant true value.
    var invertedImmidiates: Set<UInt64>
    /// Gates that have at least one constant input, and cannot be simplified away
    var users: Set<UInt64>

    func isOptimalConst(_ gateId: UInt64) -> Bool {
        return immidiates.contains(gateId) || invertedImmidiates.contains(gateId)
    }
}

private func foldConstantDrives(
    builder: SMNetBuilder,
    info: borrowing ConstantInfo,
    updated: inout Set<UInt64>
) -> [UInt64: Bool] {
    var redrives: [UInt64: Bool] = [:]

    @discardableResult
    func disconnectKeepOne(_ srcs: Set<UInt64>, to gateId: UInt64, otherwiseRedrive value: Bool) -> UInt64? {
        guard srcs.count > 0 else { return nil }
        var optimal: UInt64? = nil
        var changed: Bool = false
        for srcId in srcs {
            // prefer immidiate and immediate inverters (optimals)
            if optimal == nil, info.isOptimalConst(srcId) {
                // found optimal
                optimal = srcId
            } else {
                // disconnect remaining
                builder.disconnect(srcId, to: gateId)
                updated.insert(srcId)
                changed = true
            }
        }
        // if no optimal exists, mark to create one
        if optimal == nil {
            redrives[gateId] = value
        }
        if changed {
            updated.insert(gateId)
        }
        return optimal
    }

    func disconnectAll(_ srcs: Set<UInt64>, to gateId: UInt64) {
        if srcs.count > 0 {
            builder.disconnect(srcs, to: gateId)
            updated.formUnion(srcs)
            updated.insert(gateId)
        }
    }

    for gateId in info.users {
        let gate = builder.module.gates[gateId]!
        switch gate.type {
        case .logic(let logicType):
            assert(gate.srcs.count > 0)

            // obtain all true and false constants for analysis
            var trueConsts: Set<UInt64> = []
            var falseConsts: Set<UInt64> = []
            var others: Set<UInt64> = []

            for srcId in gate.srcs {
                switch info.constants[srcId] {
                case true:
                    trueConsts.insert(srcId)
                case false:
                    falseConsts.insert(srcId)
                case nil:
                    others.insert(srcId)
                }
            }

            switch logicType.sourceAggrigationType {
            case .logicalAnd:
                // preserve a true output if every input is true
                if trueConsts.count == gate.srcs.count {
                    disconnectKeepOne(trueConsts, to: gateId, otherwiseRedrive: true)
                    continue
                }
                // disconnect all inputs if gate is constant false
                if !logicType.isInverter, falseConsts.count > 0 {
                    disconnectAll(gate.srcs, to: gateId)
                    continue
                }
                // disconnect all trues (useless when there are other inputs)
                disconnectAll(trueConsts, to: gateId)
                // disconnect all false but one
                disconnectKeepOne(falseConsts, to: gateId, otherwiseRedrive: false)
                // disconnect all other inputs if there is a false
                if !falseConsts.isEmpty {
                    disconnectAll(others, to: gateId)
                }
            case .logicalOr:
                // preserve a false input for an inverter
                if falseConsts.count == gate.srcs.count, logicType.isInverter {
                    disconnectKeepOne(falseConsts, to: gateId, otherwiseRedrive: false)
                    continue
                }
                // disconnect all falses (useless when there are other inputs)
                disconnectAll(falseConsts, to: gateId)
                // disconnect all trues but one
                disconnectKeepOne(trueConsts, to: gateId, otherwiseRedrive: true)
                // disconnect all other inputs if there is a true
                if !trueConsts.isEmpty {
                    disconnectAll(others, to: gateId)
                }
            case .logicalParity:
                // check fanin state
                if others.isEmpty {
                    // all inputs are constant
                    // check fanin values
                    if trueConsts.count.isMultiple(of: 2) {
                        // fanin produces a false
                        // check if the input
                        if logicType.isInverter {
                            // keep negation and drive by a single false
                            disconnectKeepOne(falseConsts, to: gateId, otherwiseRedrive: false)
                            if falseConsts.isEmpty { redrives[gateId] = false }
                            disconnectAll(trueConsts, to: gateId)
                        } else {
                            // disconnect all input to produce false
                            disconnectAll(gate.srcs, to: gateId)
                        }
                    } else {
                        // fanin produces a true
                        // keep a true value
                        disconnectAll(falseConsts, to: gateId)
                        disconnectKeepOne(trueConsts, to: gateId, otherwiseRedrive: true)
                    }
                } else {
                    // have some other input
                    // disconnect all false inputs as they do nothing
                    disconnectAll(falseConsts, to: gateId)
                    // check input parity
                    if trueConsts.count.isMultiple(of: 2) {
                        // constant inputs produces a parity false
                        // remove all true inputs
                        disconnectAll(trueConsts, to: gateId)
                    } else if gate.isCombinational {
                        // constant inputs produces a parity true
                        // flip gate type if is combinational (timing insensitive)
                        builder.changeGateType(of: gateId, to: .logic(type: logicType.negatedGate))
                        disconnectAll(trueConsts, to: gateId)
                    } else {
                        // keep a true input to preserve timing
                        disconnectKeepOne(trueConsts, to: gateId, otherwiseRedrive: true)
                    }
                }
            }

        case .timer(_):
            let srcId = gate.srcs.first!
            switch info.constants[srcId] {
            case nil:
                break
            case true: // true value must be kept
                if !info.isOptimalConst(srcId) {
                    redrives[gateId] = true
                    builder.disconnect(srcId, to: gateId)
                    updated.insert(srcId)
                    updated.insert(gateId)
                }
            case false: // false value can be purged
                builder.disconnect(srcId, to: gateId)
                updated.insert(srcId)
                updated.insert(gateId)
            }
        }
    }

    return redrives
}

private func identifyConstantNodes(
    builder: SMNetBuilder
) -> ConstantInfo {
    var constants: [UInt64: Bool] = [:]
    var immidiates: Set<UInt64> = []
    var invertedImmidiates: Set<UInt64> = []
    var users: Set<UInt64> = []

    var focus: Set<UInt64> = []

    // add the initial set of dangling nodes as false
    for (gateId, gate) in builder.module.gates {
        guard gate.srcs.isEmpty,
              !builder.inputIds.contains(gateId),
              !builder.outputIds.contains(gateId)
        else { continue }

        focus.formUnion(gate.dsts)
        constants[gateId] = false
        if case .logic(_) = gate.type {
            immidiates.insert(gateId)
        }
    }

    // evaluate each constant value
    while let gateId = focus.popFirst() {
        guard let gate = builder.module.gates[gateId],
              gate.srcs.count > 0,
              !builder.outputIds.contains(gateId),
              let value = evaluate(gate, in: constants)
        else {
            users.insert(gateId)
            continue
        }

        constants[gateId] = value
        focus.formUnion(gate.dsts)

        if case .logic(let logicType) = gate.type,
           logicType.isInverter,
           gate.srcs.count == 1,
           immidiates.contains(gate.srcs.first!)
        {
            invertedImmidiates.insert(gateId)
        }
    }

    users.subtract(constants.keys)

    return ConstantInfo(
        constants: constants,
        immidiates: immidiates,
        invertedImmidiates: invertedImmidiates,
        users: users
    )
}

private func evaluate(_ gate: borrowing SMGate, in constants: borrowing [UInt64: Bool]) -> Bool? {
    // zero input gate is always false
    if gate.srcs.isEmpty { return false }

    // ensure gate is combinational
    // timing sensitive gates are only allowed if they are not an inverter

    switch gate.type {
    case .logic(let logicType):
        guard gate.isCombinational || !logicType.isInverter else { return nil }

        let trueOutput = logicType.isInverter ? false : true
        let falseValue = !trueOutput

        switch logicType.sourceAggrigationType {
        case .logicalAnd:
            var hasUnknown = false
            for srcId in gate.srcs {
                if let value = constants[srcId] {
                    // return false if any input is false
                    if value == false { return falseValue }
                } else {
                    hasUnknown = true
                }
            }
            // return true if all inputs are true
            return hasUnknown ? nil : trueOutput
        case .logicalOr:
            var hasUnknown = false
            for srcId in gate.srcs {
                if let value = constants[srcId] {
                    // return true if any input is true
                    if value == true { return trueOutput }
                } else {
                    hasUnknown = true
                }
            }
            // return false if all inputs are false
            return hasUnknown ? nil : falseValue
        case .logicalParity:
            var parity = falseValue
            for srcId in gate.srcs {
                if let value = constants[srcId] {
                    parity = parity != value
                } else {
                    // return unknown if any input is unknown
                    return nil
                }
            }
            return parity
        }

    case .timer(_):
        let srcId = gate.srcs.first!
        let value = constants[srcId]
        guard gate.isCombinational || value == false else { return nil }
        return value
    }
}

