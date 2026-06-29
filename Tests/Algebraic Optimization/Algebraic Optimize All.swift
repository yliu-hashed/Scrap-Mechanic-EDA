//
//  Algebraic Optimize All.swift
//  Scrap Mechanic EDA
//

import Testing

import SMEDANetlist

struct AlgebraicOptimizeAllTests {

    @Test("Random functional sparse network tests", arguments: 1...10)
    func testRandomSparse(seed: UInt64) throws {
        // build random network
        let config = RandomNetworkConfig(
            internalGateCount: 200,
            inputCount: 6,
            outputCount: 64,
            maxFaninLimit: 3,
            maxFanoutLimit: 64
        )

        let net = buildRandomNetwork(seed: seed, config: config)

        var optimized: SMModule = net
        algebraicOptimize(&optimized)
        try optimized.check()

        // check functional equivalance
        let sim1 = SimulationModel(module: net)
        let sim2 = SimulationModel(module: optimized)

        func eval(raw: UInt64, in sim: SimulationModel) -> UInt64 {
            #expect(sim.setInput("in", to: raw))
            #expect(sim.wrapToStable(ticks: 300))
            return sim.getOutput(of: "out")
        }

        for input: UInt64 in 0..<(1 << 6) {
            let expectation = eval(raw: input, in: sim1)
            let actual = eval(raw: input, in: sim2)
            #expect(expectation == actual)
        }
    }

    @Test("Random functional dense network tests", arguments: 1...10)
    func testRandomDense(seed: UInt64) throws {
        // build random network
        let config = RandomNetworkConfig(
            internalGateCount: 200,
            inputCount: 6,
            outputCount: 64,
            maxFaninLimit: 32,
            maxFanoutLimit: 64
        )

        let net = buildRandomNetwork(seed: seed, config: config)

        var optimized: SMModule = net
        algebraicOptimize(&optimized)
        try optimized.check()

        // check functional equivalance
        let sim1 = SimulationModel(module: net)
        let sim2 = SimulationModel(module: optimized)

        func eval(raw: UInt64, in sim: SimulationModel) -> UInt64 {
            #expect(sim.setInput("in", to: raw))
            #expect(sim.wrapToStable(ticks: 300))
            return sim.getOutput(of: "out")
        }

        for input: UInt64 in 0..<(1 << 6) {
            let expectation = eval(raw: input, in: sim1)
            let actual = eval(raw: input, in: sim2)
            #expect(expectation == actual)
        }
    }
}
