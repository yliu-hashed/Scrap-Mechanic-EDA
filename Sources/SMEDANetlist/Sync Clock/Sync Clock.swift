//
//  Sync Clock.swift
//  Scrap Mechanic EDA
//

public func syncClock(_ module: inout SMModule) {
    var clockDomains: Set<UInt64> = []
    for input in module.inputs.values {
        if input.isClock { clockDomains.formUnion(input.gates) }
    }

    for domain in clockDomains {
        syncClock(&module, clockComain: domain)
    }
}

public func syncClock(_ module: inout SMModule, clockComain: UInt64) {
    let builder = SMNetBuilder(module: module)
    ensureClockSync(builder: builder, clockComain: clockComain)

    let inputGates = module.inputs.values.lazy.map(\.gates).joined()
    let outputGates = module.outputs.values.lazy.map(\.gates).joined()
    let keepingGates = Set(inputGates).union(outputGates)

    while true {
        var changed = false
        if peepoptJoinIdenticalSibings(
            builder: builder,
            keeping: keepingGates
        ) { changed = true }
        if !changed { break }
    }

    module = builder.module
}

func ensureClockSync(builder: SMNetBuilder, clockComain: UInt64) {
    let longestPath = calcLongestPath(builder.module, clockDomain: clockComain)
    let shortestPath = calcShortestPath(builder.module, clockDomain: clockComain)
    guard longestPath != shortestPath else { return }

    var visited: Set<UInt64> = [clockComain]
    var lastNewVisited: Set<UInt64> = [clockComain]

    for _ in 0..<longestPath {
        var newVisited: Set<UInt64> = []
        for gateId in lastNewVisited {
            for dstId in builder.module.gates[gateId]!.dsts {
                if builder.module.sequentialNodes.contains(dstId) {
                    let buffer = builder.addLogic(type: .or)
                    builder.disconnect(gateId, to: dstId)
                    builder.connect(gateId, to: buffer)
                    builder.connect(buffer, to: dstId)
                }
            }
            newVisited.formUnion(builder.module.gates[gateId]!.dsts)
        }
        lastNewVisited = newVisited
        visited.formUnion(newVisited)
    }

    let newShortestPath = calcShortestPath(builder.module, clockDomain: clockComain)
    assert(newShortestPath == longestPath)
}

func calcLongestPath(_ module: SMModule, clockDomain: UInt64) -> Int {
    var visited: Set<UInt64> = [clockDomain]
    var lastNewVisited: Set<UInt64> = [clockDomain]

    var iterations = 0
    while true {
        var newVisited: Set<UInt64> = []
        for gateId in lastNewVisited {
            newVisited.formUnion(module.gates[gateId]!.dsts.lazy.filter({ !module.sequentialNodes.contains($0) }))
        }
        if newVisited.isEmpty {
            break
        }
        iterations += 1
        lastNewVisited = newVisited
        visited.formUnion(newVisited)
    }

    return iterations
}

func calcShortestPath(_ module: SMModule, clockDomain: UInt64) -> Int {
    var visited: Set<UInt64> = [clockDomain]
    var lastNewVisited: Set<UInt64> = [clockDomain]

    var iterations = 0
    while true {
        var newVisited: Set<UInt64> = []
        for gateId in lastNewVisited {
            if module.gates[gateId]!.dsts.contains(where: { module.sequentialNodes.contains($0) }) {
                return iterations
            }
            newVisited.formUnion(module.gates[gateId]!.dsts)
        }

        if newVisited.isEmpty {
            fatalError()
            break
        }
        iterations += 1
        lastNewVisited = newVisited
        visited.formUnion(newVisited)
    }

    return iterations
}
