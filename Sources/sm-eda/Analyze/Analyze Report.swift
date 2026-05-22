//
//  Analyze Report.swift
//  Scrap Mechanic EDA
//

import SMEDANetlist
import SMEDABlueprint
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

private extension SMModule {
    func dumpNet() {
        print("Gate Network:")
        print("  INPUTS: ")
        for (name, gates) in inputs {
            print("    \(name): \(gates)")
        }
        print("   OUTPUTS: ")
        for (name, gates) in outputs {
            print("    \(name): \(gates)")
        }
        print("   GATES: ")
        for (gateId, gate) in gates {
            let gateName = String(gateId)
                .padding(toLength: 4, withPad: " ", startingAt: 0)
            let gateTypeName = gate.type.description
                .padding(toLength: 4, withPad: " ", startingAt: 0)
            print("    \(gateName):\(gateTypeName) \(gate.srcs)")
        }
        print()
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
    print()
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
    print()
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
    print()
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
        print("Utilization changed by \(improvementStr)")
    }
    // check time difference
    let oldTime = old.timingReport.criticalDepth ?? 0
    let newTime = new.timingReport.criticalDepth ?? 0
    if oldTime != 0, newTime != 0, newTime != oldTime {
        let change = newTime - oldTime
        let improvement = Float(change) / Float(oldTime)
        let changeStr = (newTime - oldTime).formatted(.number.sign(strategy: .always()))
        let improvementStr = improvement.formatted(.percent.sign(strategy: .always()).precision(.fractionLength(2)))
        print("Critical depth changed by \(changeStr) (\(improvementStr))")
    }
}

// MARK: Utility
private func printItems(
    title: String = "",
    _ table: [(key: String, value: String)],
    numbered: Bool,
    minKeyWidth: Int = 25
) {
    print(title + ": ")
    var maxKey: Int = max(minKeyWidth, 0)
    for (key, _) in table {
        maxKey = max(key.count, maxKey)
    }
    if numbered {
        let digits = "\(table.count)".count
        for (index, (key, value)) in table.enumerated() {
            let prefix = (index + 1).description.padding(to: digits, left: true)
            let key = (key + ":").padding(to: maxKey - digits)
            print("   \(prefix). \(key) \(value)")
        }
    } else {
        for (key, value) in table {
            let key = (key + ":").padding(to: maxKey + 2)
            print("   \(key) \(value)")
        }
    }
}

private func timeFromTicks(_ time: Int?, nilName: String = "--") -> String {
    if let time = time {
        let realTime = (Float(time) / Float(kSMFrameRate))
        return "\(time.description) (\(realTime)s)"
    } else {
        return nilName
    }
}
