//
//  Report Printing.swift
//  Scrap Mechanic EDA
//

import SMEDANetlist
import SMEDAResult

extension String {
    func padding(to newLength: Int, with padChar: Character = " ", left: Bool = false) -> String {
        if left {
            return [Character](repeating: padChar, count: max(0, newLength - count)) + self
        } else {
            return self + [Character](repeating: padChar, count: max(0, newLength - count))
        }
    }
}

extension SMGateType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .logic(let type):
            return type.description
        case .timer(let delay):
            return "TIMER[\(delay)]"
        }
    }
}

// MARK: Dump Timing
extension TimingReport {
    var symbols: [(key: String, value: String)] {
        return [
            ("critical depth", timeFromTicks(criticalDepth)),
            ("timing type", timingType?.rawValue ?? "N/A"),
        ]
    }
}

func printTimingReport(_ timing: TimingReport) {
    printItems(title: "Timing Report", timing.symbols, numbered: true)
    printPortTimingReport(timing)
}

// MARK: Port Timing
private func printPortTimingReport(_ timing: TimingReport) {
    let inputs = timing.inputTiming.map { (key, value) in
        return (key, timeFromTicks(value))
    }
    printItems(title: "Inputs Timing", inputs, numbered: false)
    let outputs = timing.outputTiming.map { (key, value) in
        return (key, timeFromTicks(value))
    }
    printItems(title: "Outputs Timing", outputs, numbered: false)
}

// MARK: Dump Complexity
extension ComplexityReport {
    var symbols: [(key: String, value: String)] {
        return [
            ("total gate", gateCount.description),
            ("input gate", inputGateCount.description),
            ("output gate", outputGateCount.description),
            ("internal gate", internalGateCount.description),
            ("sequential internal", sequentialGateCount.description),
            ("combinational internal", combinationalGateCount.description),
            ("clock tree internal", clockTreeGateCount.description),
            ("total connection", connectionCount.description),
            ("avg fanin", averageFanin.formatted(.number.precision(.fractionLength(2)))),
        ]
    }
}

func printComplexityReport(_ report: ComplexityReport) {
    printItems(title: "Design Statistics", report.symbols, numbered: true)
}

// MARK: Lite Report
func printLiteReport(_ report: FullSynthesisReport) {
    print("Design:")
    print("   critical depth: \(timeFromTicks(report.timingReport.criticalDepth))")
    print("   gate count: \(report.complexityReport.gateCount), conn. count: \(report.complexityReport.connectionCount)")
}

// MARK: Difference
func printDifference(old: FullSynthesisReport, new: FullSynthesisReport) {
    // check size difference
    let oldUtil = old.placementReport.utilization
    let newUtil = new.placementReport.utilization
    if !oldUtil.isNaN, !newUtil.isNaN, oldUtil > 0, abs(newUtil - oldUtil) > 0.005 {
        let improvement = (newUtil - oldUtil) / oldUtil
        let improvementStr = improvement.formatted(.percent.sign(strategy: .always()).precision(.fractionLength(2)))
        print("Utilization changed by \(improvementStr).")
    }
    // check time difference
    let oldTime = old.timingReport.criticalDepth ?? 0
    let newTime = new.timingReport.criticalDepth ?? 0
    if oldTime != 0, newTime != 0, newTime != oldTime {
        let change = newTime - oldTime
        let improvement = Float(change) / Float(oldTime)
        let changeStr = (newTime - oldTime).formatted(.number.sign(strategy: .always()))
        let improvementStr = improvement.formatted(.percent.sign(strategy: .always()).precision(.fractionLength(2)))
        print("Critical depth changed by \(changeStr) (\(improvementStr)).")
    }
}
