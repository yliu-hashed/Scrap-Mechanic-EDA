//
//  Optimize Function.swift
//  Scrap Mechanic EDA
//

import ArgumentParser
import SMEDANetlist

struct OptimizerArgGroup: ParsableArguments {
    @Flag(name: [.customLong("no-opt")])
    var noOptimize: Bool = false

    func work(module: inout SMModule) throws {
        if !noOptimize {
            optimize(&module)
        } else {
            syncClock(&module)
        }
    }
}
