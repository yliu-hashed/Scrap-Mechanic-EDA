//
//  Placement - Conn Opt.swift
//  Scrap Mechanic EDA
//

import SMEDANetlist
import SMEDABlueprint

// compute the cost of a gate within the placement
private func cost(
    of gateId: UInt64,
    at pos: SMVector,
    in mapping: borrowing [UInt64: SMVector],
    for module: borrowing SMModule
) -> Int {
    var cost: Int = 0
    let gate = module.gates[gateId]!
    for otherId in gate.srcs {
        let otherPos = mapping[otherId]!
        cost += (otherPos - pos).distanceSquared
    }
    for otherId in gate.dsts {
        let otherPos = mapping[otherId]!
        cost += (otherPos - pos).distanceSquared
    }
    return cost
}

private func anneal(
    _ mapping: inout [UInt64: SMVector],
    for module: borrowing SMModule,
    working: inout Set<UInt64>,
    maxRangeSquared: Int
) -> Int {
    var newWorking: Set<UInt64> = []
    newWorking.reserveCapacity(working.count)

    var maxMovementSquared: Int = 0

    // loop for every pair of gate
    for gateAId in working {
        let posA = mapping[gateAId]!
        let costAA = cost(of: gateAId, at: posA, in: mapping, for: module)

        var changed: Bool = false

        for gateBId in working where gateAId != gateBId {
            let posB = mapping[gateBId]!
            // skip if too far
            let distanceSquared = (posA - posB).distanceSquared
            if distanceSquared - 1 > maxRangeSquared { continue }
            // get the cost if A at it's own location
            let costBB = cost(of: gateBId, at: posB, in: mapping, for: module)
            // get the cost if A is at B
            let costAB = cost(of: gateAId, at: posB, in: mapping, for: module)
            // early return (very likley)
            if costAB > costAA + costBB { continue }
            // get the cost if B is at A
            let costBA = cost(of: gateBId, at: posA, in: mapping, for: module)
            // swap if the cost is lower
            if costAB + costBA < costAA + costBB {
                mapping[gateAId] = posB
                mapping[gateBId] = posA
                changed = true
                // record movement distance
                let distanceSquared = (posA - posB).distanceSquared
                maxMovementSquared = max(maxMovementSquared, distanceSquared)
                break
            }
        }

        if changed {
            newWorking.insert(gateAId)
        }
    }
    working = newWorking
    return maxMovementSquared
}

private func computeCost(
    for mapping: borrowing [UInt64: SMVector],
    in module: borrowing SMModule
) -> Int {
    var cost: Int = 0
    for (gateId, gate) in module.gates {
        let pos = mapping[gateId]!
        for otherId in gate.srcs {
            let pos2 = mapping[otherId]!
            cost += (pos - pos2).distanceSquared
        }
        for otherId in gate.dsts {
            let pos2 = mapping[otherId]!
            cost += (pos - pos2).distanceSquared
        }
    }
    return cost
}

func optimizeConnections(
    of mapping: inout [UInt64: SMVector],
    for module: borrowing SMModule,
    logicGates: Set<UInt64>,
    effort: Float,
    verbose: Bool
) {

    if verbose { print("Optimizing connections with effort \(effort)") }

    let initialCost = computeCost(for: mapping, in: module)

    if verbose { print("   Initial cost: \(initialCost)") }

    var prevCost = initialCost

    func annealFineRound() {
        if verbose { print("   Round Begin") }
        var working = logicGates
        var maxRangeEquared: Int = .max
        while !working.isEmpty, maxRangeEquared >= 2 {
            // optimize one time
            maxRangeEquared = anneal(
                &mapping,
                for: module,
                working: &working,
                maxRangeSquared: maxRangeEquared
            )
            let newCost = computeCost(for: mapping, in: module)
            let stop = Double(newCost) >= Double(prevCost) * Double(effort)
            if verbose { print("   Step cost: \(newCost)") }
            prevCost = newCost
            if stop { break }
        }
    }

    annealFineRound()
    annealFineRound()
    annealFineRound()

    if verbose {
        let improvement = 1 - Float(prevCost) / Float(initialCost)
        print("   Connections optimized by \(improvement.formatted(.percent.precision(.fractionLength(2))))")
        print()
    }
}
