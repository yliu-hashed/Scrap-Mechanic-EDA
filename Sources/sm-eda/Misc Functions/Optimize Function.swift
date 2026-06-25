//
//  Optimize Function.swift
//  Scrap Mechanic EDA
//

import ArgumentParser
import SMEDANetlist

struct OptimizerArgGroup: ParsableArguments {
    @Flag(name: [.customLong("no-opt")])
    var noOptimize: Bool = false

    func work(module: inout SMModule, printlevel: PrintLevel) throws {
        if !noOptimize {
            if printlevel == .verbose {
                print("Optimizing module '\(module.name)' using algebraic methods.")
            }
            algebraicOptimize(&module) { step, reduction in
                if printlevel == .verbose {
                    print("   Step \(step) reduced \(reduction) gates.")
                }
            }
        } else {
            syncClock(&module)
        }
    }
}
