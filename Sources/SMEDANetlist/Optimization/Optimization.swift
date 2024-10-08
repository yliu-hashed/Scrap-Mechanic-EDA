//
//  Optimization.swift
//  Scrap Mechanic EDA
//

func isInLoop(module: SMModule, nodeId: UInt64) -> Bool {
    for srcId in module.gates[nodeId]!.srcs {
        for srcId2 in module.gates[srcId]!.srcs {
            if module.gates[srcId2]!.srcs.contains(nodeId) {
                return true
            }
        }
    }
    return false
}

public func optimize(_ module: inout SMModule) {

    let builder = SMNetBuilder(module: module)

    let inputGates = module.inputs.values.lazy.map(\.gates).joined()
    let outputGates = module.outputs.values.lazy.map(\.gates).joined()
    let keepingGates = Set(inputGates).union(outputGates)

    var passCounter: Int = 0
    while true {
        passCounter += 1
        var changed = false

        if peepoptConstFold(
            builder: builder,
            keeping: keepingGates
        ) { changed = true }

        if peepoptPurgePort(
            builder: builder
        ) { changed = true }

        if peepoptJoinIdenticalSibings(
            builder: builder,
            keeping: keepingGates
        ) { changed = true }

        if peepoptReduceBuffers(
            builder: builder,
            keeping: keepingGates
        ) { changed = true }

        if peepoptReduceInverters(
            builder: builder,
            keeping: keepingGates
        ) { changed = true }

        if !changed { break }

        module = builder.module
    }

    // sync clock domain
    syncClock(&module)
}
