//
//  Sync Clock.swift
//  Scrap Mechanic EDA
//

public func syncClock(_ module: inout SMModule, domains: Set<UInt64>? = nil) {
    var clockDomains: Set<UInt64> = []
    if let domains = domains {
        clockDomains = domains
    } else {
        for input in module.inputs.values {
            if input.isClock { clockDomains.formUnion(input.gates) }
        }
    }

    let builder = SMNetBuilder(module: module)

    for domain in clockDomains {
        ensureClockSync(builder: builder, clockComain: domain)
    }

    var live: Set<UInt64> = []
    for (gateId, gate) in module.gates {
        guard gate.isClockTree else { continue }
        live.insert(gateId)
    }

    while !live.isEmpty {
        var newLive: Set<UInt64> = []
        algebraicMergeIdentical(
            builder: builder,
            intrest: live,
            updated: &newLive
        )
        live = newLive
    }

    module = builder.module
}

func syncClock(_ module: inout SMModule, clockComain: UInt64) {
    let builder = SMNetBuilder(module: module)
    ensureClockSync(builder: builder, clockComain: clockComain)
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
                let dst = builder.module.gates[dstId]!
                if dst.isSequential {
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
            for dstId in module.gates[gateId]!.dsts {
                if !module.gates[dstId]!.isClockTree { continue }
                newVisited.insert(dstId)
            }
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
            for dstId in module.gates[gateId]!.dsts {
                if !module.gates[dstId]!.isClockTree { return iterations }
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
