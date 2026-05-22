//
//  Analyze Complexity.swift
//  Scrap Mechanic EDA
//

import SMEDANetlist
import SMEDAResult

func analyzeComplexity(_ module: borrowing SMModule) -> ComplexityReport {
    // all gate count
    let gateCount = module.gates.count
    // input gate count
    var inputs: Set<UInt64> = []
    for (_, port) in module.inputs {
        inputs.formUnion(port.gates)
    }
    // output gate count
    var outputs: Set<UInt64> = []
    for (_, port) in module.outputs {
        outputs.formUnion(port.gates)
    }

    // internal gate count
    var combinationalGateCount = 0
    var sequentialGateCount = 0
    var clockTreeGateCount = 0
    for (gateId, gate) in module.gates {
        if inputs.contains(gateId) || outputs.contains(gateId) { continue }
        switch gate.domain {
        case .combinational:
            combinationalGateCount += 1
        case .clockTree:
            clockTreeGateCount += 1
        case .sequential:
            sequentialGateCount += 1
        }
    }

    // connection count
    var connCount: Int = 0
    for (_, gate) in module.gates { connCount += gate.srcs.count }
    // average gate input count
    let avgGateInput: Float = Float(connCount) / Float(gateCount)

    var report = ComplexityReport()

    report.gateCount = gateCount
    report.inputGateCount = inputs.count
    report.outputGateCount = outputs.count
    report.internalGateCount = gateCount - inputs.count - outputs.count
    report.sequentialGateCount = sequentialGateCount
    report.combinationalGateCount = combinationalGateCount
    report.clockTreeGateCount = clockTreeGateCount
    report.connectionCount = connCount
    report.averageGateInputCount = avgGateInput

    return report
}
