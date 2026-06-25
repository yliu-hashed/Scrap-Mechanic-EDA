//
//  Optimization.swift
//  Scrap Mechanic EDA
//

public typealias AlgebraicOptimizationProgress = (_ step: Int, _ reduction: Int)->Void

public func algebraicOptimize(_ module: inout SMModule, progress: AlgebraicOptimizationProgress? = nil) {

    let builder = SMNetBuilder(module: module)
    var live: Set<UInt64> = Set(module.gates.keys)

    var stepCount: Int = 1

    while !live.isEmpty {
        var nextLive: Set<UInt64> = []

        let prevCount = builder.module.gates.count

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

        if let progress = progress {
            progress(stepCount, prevCount - currCount)
        }
        live = nextLive
        stepCount += 1
    }
    module = builder.module

    // sync clock domain
    syncClock(&module)
}
