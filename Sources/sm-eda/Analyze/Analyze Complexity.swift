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
    var inputGateCount: Int = 0
    for (_, port) in module.inputs {
        inputGateCount += port.gates.count
    }
    // output gate count
    var outputGateCount: Int = 0
    for (_, port) in module.outputs {
        outputGateCount += port.gates.count
    }
    // internal gate count
    let internalGateCount = gateCount - inputGateCount - outputGateCount
    // sequential gate count
    let sequentialGateCount = module.sequentialNodes.count
    let combinationalGateCount = internalGateCount - sequentialGateCount
    // connection count
    var connCount: Int = 0
    for (_, gate) in module.gates { connCount += gate.srcs.count }
    // average gate input count
    let avgGateInput: Float = Float(connCount) / Float(gateCount)

    var report = ComplexityReport()

    report.gateCount = gateCount
    report.inputGateCount = inputGateCount
    report.outputGateCount = outputGateCount
    report.internalGateCount = internalGateCount
    report.sequentialGateCount = sequentialGateCount
    report.combinationalGateCount = combinationalGateCount
    report.connectionCount = connCount
    report.averageGateInputCount = avgGateInput

    return report
}
