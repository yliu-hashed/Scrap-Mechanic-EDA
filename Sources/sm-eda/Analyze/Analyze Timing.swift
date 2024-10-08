//
//  Analyze Timing.swift
//  Scrap Mechanic EDA
//

import SMEDANetlist
import SMEDAResult

func analyzeTiming(_ module: borrowing SMModule) -> TimingReport {
    let fwdTable = traverse(module, isRev: true)
    let revTable = traverse(module, isRev: false)

    let totalDepth = fwdTable.values.max() ?? 0

    var inputTiming: [String: Int] = [:]
    inputTiming.reserveCapacity(module.inputs.count)
    var outputTiming: [String: Int] = [:]
    outputTiming.reserveCapacity(module.outputs.count)

    for portName in module.inputs.keys {
        let delay = getAcylicDepth(ofInput: portName, in: module, using: fwdTable)
        inputTiming[portName] = delay
    }
    for portName in module.outputs.keys {
        let delay = getAcylicDepth(ofOutput: portName, in: module, using: revTable)
        outputTiming[portName] = delay
    }

    var report = TimingReport()

    let isPureComb = module.sequentialNodes.isEmpty

    report.criticalDepth = isPureComb ? totalDepth : totalDepth + 2
    report.timingType = isPureComb ? .combinational : .sequential
    report.inputTiming = inputTiming
    report.outputTiming = outputTiming

    return report
}

extension SMGate {
    func nexts(isRev: Bool) -> Set<UInt64> {
        return isRev ? srcs : dsts
    }

    func prevs(isRev: Bool) -> Set<UInt64> {
        return isRev ? dsts : srcs
    }

    func nextPortals(isRev: Bool) -> Dictionary<UInt64, Int> {
        return isRev ? portalSrcs : portalDsts
    }

    func prevPortals(isRev: Bool) -> Dictionary<UInt64, Int> {
        return isRev ? portalDsts : portalSrcs
    }
}

private func traverse(_ module: borrowing SMModule, isRev: Bool) -> [UInt64: Int] {
    var table: [UInt64: Int] = [:]
    table.reserveCapacity(module.gates.count)

    func addNext(_ gate: borrowing SMGate, to set: inout Set<UInt64>) {
        for nextId in gate.nexts(isRev: isRev) where !table.keys.contains(nextId) {
            set.insert(nextId)
        }
        for nextId in gate.nextPortals(isRev: isRev).keys where !table.keys.contains(nextId) {
            set.insert(nextId)
        }
    }

    // build initial set of timings
    var crossSection: Set<UInt64> = []
    for (gateId, gate) in module.gates {
        let isSequential = module.sequentialNodes.contains(gateId)
        guard gate.prevs(isRev: isRev).isEmpty || isSequential,
              gate.prevPortals(isRev: isRev).isEmpty else { continue }
        table[gateId] = isSequential ? 0 : 1
        addNext(gate, to: &crossSection)
    }

    func satisfied(_ gateId: UInt64) -> Int? {
        let gate = module.gates[gateId]!
        let isSequential = module.sequentialNodes.contains(gateId)
        var depthMax: Int = 0
        for prevId in gate.prevs(isRev: isRev) {
            guard let depth = table[prevId] else { return nil }
            depthMax = max(depthMax, depth + 1)
        }
        for (portalId, additional) in gate.prevPortals(isRev: isRev) {
            guard let depth = table[portalId] else { return nil }
            depthMax = max(depthMax, depth + additional)
        }
        return depthMax + (isSequential ? -1 : 0)
    }

    while !crossSection.isEmpty {
        var newCross: Set<UInt64> = []
        var changed = false
        for gateId in crossSection where !table.keys.contains(gateId) {
            if let depth = satisfied(gateId) {
                let gate = module.gates[gateId]!
                table[gateId] = depth
                addNext(gate, to: &newCross)
                changed = true
            } else {
                newCross.insert(gateId)
            }
        }
        if !changed { break }
        crossSection = newCross
    }

    return table
}

private func getAcylicDepth(ofInput portName: String, in module: borrowing SMModule, using table: borrowing [UInt64: Int]) -> Int {
    let bits = module.inputs[portName]!.gates
    var maxDepth: Int = 0
    for gateId in bits {
        maxDepth = max(maxDepth, table[gateId] ?? 0)
    }
    return maxDepth
}

private func getAcylicDepth(ofOutput portName: String, in module: borrowing SMModule, using table: borrowing [UInt64: Int]) -> Int {
    let bits = module.outputs[portName]!.gates
    var maxDepth: Int = 0
    for gateId in bits {
        maxDepth = max(maxDepth, table[gateId] ?? 0)
    }
    return maxDepth
}
