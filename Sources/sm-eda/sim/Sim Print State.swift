//
//  Sim Print State.swift
//  Scrap Mechanic EDA
//

import SMEDANetlist

private let kBitsPerLine = 32

extension SimulationModel {
    func printState() {
        // print time
        print()
        print("==== SIM STATE ===================================")
        if isInstable || willChange {
            setPrintColor(to: .red)
            print(" INSTABLE ", terminator: "")
            setPrintColor(to: .default)
            let justBegan = !isInstable && willChange
            print("(for \(justBegan ? 0 : instableCount) ticks)")
        } else {
            setPrintColor(to: .green)
            print(" STABLE ", terminator: "")
            setPrintColor(to: .default)
            print("(was instable for \(instableCount) ticks)")
        }
        // print outputs
        print("---- OUTPUTS -------------------------------------")
        for name in module.outputs.keys.sorted() {
            let gates = module.outputs[name]!.gates
            print(" \(name):")
            printPortGates(gates: gates)
        }
        // print inputs
        print("---- INPUTS --------------------------------------")
        for name in module.inputs.keys.sorted() {
            let gates = module.inputs[name]!.gates
            print(" \(name):")
            printPortGates(gates: gates)
        }
        print("==================================================")
    }

    func printPortGates(gates: borrowing [UInt64]) {
        let lines = (gates.count + kBitsPerLine - 1) / kBitsPerLine
        for l in (0..<lines).reversed() {
            let isLastLine = l == lines - 1
            let isFirstLine = l == 0
            // print line header
            if isLastLine {
                print("     [", terminator: "")
            } else {
                print("      ", terminator: "")
            }

            // print line value
            for i in (0..<kBitsPerLine).reversed() {
                let index = i + l * kBitsPerLine

                if i % 4 == 3 {
                    print(" ", terminator: "")
                }

                if gates.indices.contains(index) {
                    let gateId = gates[i]
                    let state = output(of: gateId)
                    setPrintColor(to:  state ? .cyan : .blue)
                    print(state ? "1" : "0", terminator: "")
                    setPrintColor(to: .default)
                } else {
                    print(" ", terminator: "")
                }
            }

            // print line tail
            if (isFirstLine) {
                print(" ]")
            } else {
                print(" ]")
            }
        }
    }
}
