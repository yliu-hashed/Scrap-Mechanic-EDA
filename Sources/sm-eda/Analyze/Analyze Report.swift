//
//  Analyze Report.swift
//  Scrap Mechanic EDA
//

import Foundation
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

private let deltaPercentFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.localizesFormat = false
    formatter.numberStyle = .percent
    formatter.plusSign = "+"
    formatter.minusSign = "-"
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = 2
    return formatter
}()

private let deltaFloatFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.localizesFormat = false
    formatter.numberStyle = .decimal
    formatter.plusSign = "+"
    formatter.minusSign = "-"
    formatter.maximumFractionDigits = 2
    formatter.minimumFractionDigits = 2
    return formatter
}()

private let deltaIntFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.localizesFormat = false
    formatter.numberStyle = .decimal
    formatter.plusSign = "+"
    formatter.minusSign = "-"
    return formatter
}()

private let fractionFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.localizesFormat = false
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 3
    formatter.minimumFractionDigits = 3
    return formatter
}()

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

// MARK: Dump Transformation
func printTransformationStats(_ transformRecord: [String: Int]) {
    let reported = Dictionary(uniqueKeysWithValues: transformRecord.map { (key, value) in
        return (key, String(value))
    })
    printItems(title: "Transformation Stats", reported)
    print()
}

// MARK: Dump Timing
extension TimingReport {
    var symbols: [String: String] {
        return [
            "1. critical depth": timeFromTicks(criticalDepth),
            "2. timing type": timingType?.rawValue ?? "N/A",
        ]
    }
}

func printTimingReport(_ timing: TimingReport) {
    printItems(title: "Timing Report", timing.symbols)
    print()
    printPortTimingReport(timing)
}

// MARK: Port Timing
private func printPortTimingReport(_ timing: TimingReport) {
    let inputs = Dictionary(uniqueKeysWithValues: timing.inputTiming.map { (key, value) in
        return (key, timeFromTicks(value))
    })
    printItems(title: "Inputs Timing", inputs)
    let outputs = Dictionary(uniqueKeysWithValues: timing.outputTiming.map { (key, value) in
        return (key, timeFromTicks(value))
    })
    printItems(title: "Outputs Timing", outputs)
    print()
}

// MARK: Dump Complexity
extension ComplexityReport {
    var symbols: [String: String] {
        return [
            " 1. total gate": gateCount.description,
            " 2. input gate": inputGateCount.description,
            " 3. output gate": outputGateCount.description,
            " 4. internal gate": internalGateCount.description,
            " 5. sequential internal": sequentialGateCount.description,
            " 6. combinational internal": combinationalGateCount.description,
            " 7. total connection": connectionCount.description,
            " 8. avg gate input": fractionFormatter.string(from: NSNumber(value: averageGateInputCount))!,
        ]
    }
}

func printComplexityReport(_ report: ComplexityReport) {
    printItems(title: "Design Statistics", report.symbols)
    print()
}

// MARK: Lite Report
func printLiteReport(_ report: FullSynthesisReport) {
    print("Design:")
    print("   critical depth: \(timeFromTicks(report.timingReport.criticalDepth))")
    print("   gate count: \(report.complexityReport.gateCount), conn. count: \(report.complexityReport.connectionCount)")
}

// MARK: Utility
private func printItems(title: String = "", _ dict: [String: String], minKeyWidth: Int = 27) {
    print(title + ": ")
    var maxKey: Int = max(minKeyWidth, 0)
    for key in dict.keys {
        maxKey = max(key.count, maxKey)
    }
    for (key, value) in dict.sorted(by: { $0.key < $1.key }) {
        print("   ", terminator: "")
        print("\(key): ".padding(to: maxKey + 2), terminator: "")
        print(value)
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
