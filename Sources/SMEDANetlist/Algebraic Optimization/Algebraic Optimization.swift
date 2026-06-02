//
//  Optimization.swift
//  Scrap Mechanic EDA
//

public func algebraicOptimize(_ module: inout SMModule, verbose: Bool = false) {

    if verbose { print("Begin Optimization") }

    let builder = SMNetBuilder(module: module)
    var live: Set<UInt64> = Set(module.gates.keys)

    var stepCount: Int = 1

    while !live.isEmpty {
        var nextLive: Set<UInt64> = []

        let prevCount = builder.module.gates.count

        if verbose { print("   Step \(stepCount):") }

        removeUnusedInputs(
            builder: builder
        )

        algebraicMergeIdentical(
            builder: builder,
            intrest: live,
            updated: &nextLive
        )

        algebraicReduceXORNegate(
            builder: builder,
            intrest: live,
            updated: &nextLive
        )

        algebraicReduceBuffersAndInverters(
            builder: builder,
            intrest: live,
            updated: &nextLive
        )

        algebraicPurgeDangling(
            builder: builder,
            intrest: live,
            updated: &nextLive
        )

        algebraicConstFold(
            builder: builder,
            updated: &nextLive
        )

        let currCount = builder.module.gates.count
        print("      Optimized out \(prevCount - currCount) gates")
        live = nextLive
        stepCount += 1
    }
    module = builder.module

    // sync clock domain
    syncClock(&module)
}
