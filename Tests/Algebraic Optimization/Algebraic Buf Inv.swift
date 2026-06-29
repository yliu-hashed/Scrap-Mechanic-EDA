//
//  Algebraic Buf Inv.swift
//  Scrap Mechanic EDA
//

import Testing

@testable import SMEDANetlist

struct AlgebraicBufInvTests {

    @Test("Optimize 8-long buffer chain")
    func testBufChain8() throws {
        // build network of 8 long buffer chain
        let builder = SMNetBuilder()
        let i1 = builder.addLogic(type: .or)
        let g1 = builder.addLogic(type: .and)
        let g2 = builder.addLogic(type: .xor)
        let g3 = builder.addLogic(type: .or)
        let g4 = builder.addLogic(type: .and)
        let g5 = builder.addLogic(type: .or)
        let g6 = builder.addLogic(type: .xor)
        let o1 = builder.addLogic(type: .or)
        builder.connect(chain: i1, g1, g2, g3, g4, g5, g6, o1)
        builder.registerInputGates(port: "in", gates: [i1])
        builder.registerOutputGates(port: "out", gates: [o1])
        try builder.module.check()

        // test behavior
        var updated: Set<UInt64> = []
        algebraicReduceBuffersAndInverters(
            builder: builder,
            intrest: Set(builder.module.gates.keys),
            updated: &updated
        )

        // check module is well formed
        try builder.module.check()

        // check ports are intact
        #expect(builder.module.gates.keys.contains(i1))
        #expect(builder.module.gates.keys.contains(o1))
        #expect(builder.module.gates[i1]?.type == .logic(type: .or))
        #expect(builder.module.gates[o1]?.type == .logic(type: .or))

        // check chain middle is optimized away
        #expect(!builder.module.gates.keys.contains(g1))
        #expect(!builder.module.gates.keys.contains(g2))
        #expect(!builder.module.gates.keys.contains(g3))
        #expect(!builder.module.gates.keys.contains(g4))
        #expect(!builder.module.gates.keys.contains(g5))
        #expect(!builder.module.gates.keys.contains(g6))

        // check live list is properly updated
        #expect(updated.contains(i1))
        #expect(updated.contains(o1))
    }

    @Test("Optimize 8-long buffer-inverter chain (cancelled inverters)")
    func testBufInvChain8Cancelled() throws {
        // build network of 5 long buffer chain
        let builder = SMNetBuilder()
        let i1 = builder.addLogic(type: .or)
        let g1 = builder.addLogic(type: .and)
        let g2 = builder.addLogic(type: .xnor)
        let g3 = builder.addLogic(type: .nor)
        let g4 = builder.addLogic(type: .or)
        let g5 = builder.addLogic(type: .nand)
        let g6 = builder.addLogic(type: .xnor)
        let o1 = builder.addLogic(type: .or)
        builder.connect(chain: i1, g1, g2, g3, g4, g5, g6, o1)
        builder.registerInputGates(port: "in", gates: [i1])
        builder.registerOutputGates(port: "out", gates: [o1])
        try builder.module.check()

        // test behavior
        var updated: Set<UInt64> = []
        algebraicReduceBuffersAndInverters(
            builder: builder,
            intrest: Set(builder.module.gates.keys),
            updated: &updated
        )
        try builder.module.check()

        // check ports are intact
        #expect(builder.module.gates.keys.contains(i1))
        #expect(builder.module.gates.keys.contains(o1))
        #expect(builder.module.gates[i1]?.type == .logic(type: .or))
        #expect(builder.module.gates[o1]?.type == .logic(type: .or))

        // check chain middle is optimized away
        #expect(!builder.module.gates.keys.contains(g1))
        #expect(!builder.module.gates.keys.contains(g2))
        #expect(!builder.module.gates.keys.contains(g3))
        #expect(!builder.module.gates.keys.contains(g4))
        #expect(!builder.module.gates.keys.contains(g5))
        #expect(!builder.module.gates.keys.contains(g6))

        // check live list is properly updated
        #expect(updated.contains(i1))
        #expect(updated.contains(o1))
    }

    @Test("Optimize 5-long buffer-inverter chain (inverted)")
    func testBufInvChain5Inverted() throws {
        // build network of 5 long buffer chain
        let builder = SMNetBuilder()
        let i1 = builder.addLogic(type: .or)
        let g1 = builder.addLogic(type: .xor)
        let g2 = builder.addLogic(type: .nand)
        let g3 = builder.addLogic(type: .nor)
        let g4 = builder.addLogic(type: .or)
        let g5 = builder.addLogic(type: .nand)
        let g6 = builder.addLogic(type: .xor)
        let o1 = builder.addLogic(type: .or)
        builder.connect(chain: i1, g1, g2, g3, g4, g5, g6, o1)
        builder.registerInputGates(port: "in", gates: [i1])
        builder.registerOutputGates(port: "out", gates: [o1])
        try builder.module.check()

        // test behavior
        var updated: Set<UInt64> = []
        algebraicReduceBuffersAndInverters(
            builder: builder,
            intrest: Set(builder.module.gates.keys),
            updated: &updated
        )
        try builder.module.check()

        // check ports are intact
        #expect(builder.module.gates.keys.contains(i1))
        #expect(builder.module.gates.keys.contains(o1))
        #expect(builder.module.gates[i1]?.type == .logic(type: .or))
        #expect(builder.module.gates[o1]?.type == .logic(type: .or))

        // check an inverter is kept
        var maybeInverter: UInt64? = nil
        if builder.module.gates.keys.contains(g1) { maybeInverter = g1 }
        if builder.module.gates.keys.contains(g2) { maybeInverter = g2 }
        if builder.module.gates.keys.contains(g3) { maybeInverter = g3 }
        if builder.module.gates.keys.contains(g4) { maybeInverter = g4 }
        if builder.module.gates.keys.contains(g5) { maybeInverter = g5 }
        if builder.module.gates.keys.contains(g6) { maybeInverter = g6 }
        let inverter = try #require(maybeInverter)

        // check chain middle is optimized away
        #expect(inverter == g1 || !builder.module.gates.keys.contains(g1))
        #expect(inverter == g2 || !builder.module.gates.keys.contains(g2))
        #expect(inverter == g3 || !builder.module.gates.keys.contains(g3))
        #expect(inverter == g4 || !builder.module.gates.keys.contains(g4))
        #expect(inverter == g5 || !builder.module.gates.keys.contains(g5))
        #expect(inverter == g6 || !builder.module.gates.keys.contains(g6))

        // check live list is properly updated
        #expect(updated.contains(i1))
        #expect(updated.contains(o1))
        #expect(updated.contains(inverter))

        // check inverter is inverting
        guard case .logic(let type) = builder.module.gates[inverter]!.type else { fatalError() }
        #expect(type.isInverter)
    }

    @Test("Optimize inverter XOR special case")
    func testBufInvXORSpecialCase() throws {
        // build network of 5 long buffer chain
        let builder = SMNetBuilder()
        let i1 = builder.addLogic(type: .or)
        let n1 = builder.addLogic(type: .or)
        let o1 = builder.addLogic(type: .xor)
        builder.connect(chain: i1, n1, o1)
        builder.connect(i1, to: o1)
        builder.registerInputGates(port: "in", gates: [i1])
        builder.registerOutputGates(port: "out", gates: [o1])
        try builder.module.check()

        // test behavior
        var updated: Set<UInt64> = []
        algebraicReduceBuffersAndInverters(
            builder: builder,
            intrest: Set(builder.module.gates.keys),
            updated: &updated
        )
        try builder.module.check()

        // check ports are intact
        #expect(builder.module.gates.keys.contains(i1))
        #expect(builder.module.gates.keys.contains(o1))
        #expect(builder.module.gates[i1]?.type == .logic(type: .or))
        #expect(builder.module.gates[o1]?.type == .logic(type: .xor))

        // check inverter is purged
        #expect(builder.module.gates[n1] == nil)
        #expect(builder.module.gates[o1]?.type == .logic(type: .xor))

        // check input is disconencted
        #expect(builder.module.gates[o1]?.srcs == [])

        // check live list is properly updated
        #expect(updated.contains(i1))
        #expect(updated.contains(o1))
    }


}
