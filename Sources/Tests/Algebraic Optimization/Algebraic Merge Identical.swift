//
//  Algebraic Merge Identical.swift
//  Scrap Mechanic EDA
//

import Testing

@testable import SMEDANetlist

struct AlgebraicMergeIdenticalTests {

    @Test("Optimize 2 identical OR")
    func testMerge2OR() throws {
        // build network of 8 long buffer chain
        let builder = SMNetBuilder()
        let i1 = builder.addLogic(type: .or)
        let i2 = builder.addLogic(type: .or)
        let i3 = builder.addLogic(type: .or)
        let g1 = builder.addLogic(type: .or)
        let g2 = builder.addLogic(type: .or)
        let o1 = builder.addLogic(type: .or)
        let o2 = builder.addLogic(type: .or)
        builder.connect([i1, i2, i3], to: g1)
        builder.connect([i1, i2, i3], to: g2)
        builder.connect(g1, to: o1)
        builder.connect(g2, to: o2)
        builder.registerInputGates(port: "in", gates: [i1, i2, i3])
        builder.registerOutputGates(port: "out", gates: [o1, o2])
        try builder.module.check()

        // test behavior
        var updated: Set<UInt64> = []
        algebraicMergeIdentical(
            builder: builder,
            intrest: Set(builder.module.gates.keys),
            updated: &updated
        )

        // check module is well formed
        try builder.module.check()

        // check ports are intact
        let gates = builder.module.gates
        #expect(gates.count == 6)
        #expect(gates.keys.contains(i1))
        #expect(gates.keys.contains(i2))
        #expect(gates.keys.contains(i3))
        #expect(gates.keys.contains(o1))
        #expect(gates.keys.contains(o2))

        // check the transfered gate is good
        let g = gates.keys.contains(g1) ? g1 : g2
        #expect(gates.keys.contains(g))
        #expect(gates[g]?.srcs == [i1, i2, i3])
        #expect(gates[g]?.dsts == [o1, o2])

        // check live list is properly updated
        #expect(updated.contains(i1))
        #expect(updated.contains(i2))
        #expect(updated.contains(i3))
        #expect(updated.contains(o1))
        #expect(updated.contains(o2))
        #expect(updated.contains(g))
    }

    @Test("Optimize 2 identical AND going into a XOR gate (const 0)")
    func testMerge2ANDIntoXOR() async throws {
        // build network of 8 long buffer chain
        let builder = SMNetBuilder()
        let i1 = builder.addLogic(type: .or)
        let i2 = builder.addLogic(type: .or)
        let i3 = builder.addLogic(type: .or)
        let g1 = builder.addLogic(type: .and)
        let g2 = builder.addLogic(type: .and)
        let x1 = builder.addLogic(type: .xor)
        let o1 = builder.addLogic(type: .or)
        builder.connect([i1, i2, i3], to: g1)
        builder.connect([i1, i2, i3], to: g2)
        builder.connect([g1, g2], to: x1)
        builder.connect(x1, to: o1)
        builder.registerInputGates(port: "in", gates: [i1, i2, i3])
        builder.registerOutputGates(port: "out", gates: [o1])
        try builder.module.check()

        // test behavior
        var updated: Set<UInt64> = []
        algebraicMergeIdentical(
            builder: builder,
            intrest: Set(builder.module.gates.keys),
            updated: &updated
        )

        // check module is well formed
        try builder.module.check()

        let gates = builder.module.gates

        // check ports are intact
        #expect(gates.count == 6)
        #expect(gates.keys.contains(i1))
        #expect(gates.keys.contains(i2))
        #expect(gates.keys.contains(i3))
        #expect(gates.keys.contains(o1))
        #expect(gates.keys.contains(x1))

        // check XOR is not driven driven
        let xor = gates[x1]!
        #expect(xor.srcs.count == 0)
        #expect(xor.type == .logic(type: .xor))

        // check live list is properly updated
        #expect(updated.contains(i1))
        #expect(updated.contains(i2))
        #expect(updated.contains(i3))
    }

    @Test("Optimize 2 identical AND going into a XNOR gate (const 1)")
    func testMerge2ANDIntoXNOR() throws {
        // build network of 8 long buffer chain
        let builder = SMNetBuilder()
        let i1 = builder.addLogic(type: .or)
        let i2 = builder.addLogic(type: .or)
        let i3 = builder.addLogic(type: .or)
        let g1 = builder.addLogic(type: .and)
        let g2 = builder.addLogic(type: .and)
        let x1 = builder.addLogic(type: .xnor)
        let o1 = builder.addLogic(type: .or)
        builder.connect([i1, i2, i3], to: g1)
        builder.connect([i1, i2, i3], to: g2)
        builder.connect([g1, g2], to: x1)
        builder.connect(x1, to: o1)
        builder.registerInputGates(port: "in", gates: [i1, i2, i3])
        builder.registerOutputGates(port: "out", gates: [o1])
        try builder.module.check()

        // test behavior
        var updated: Set<UInt64> = []
        algebraicMergeIdentical(
            builder: builder,
            intrest: Set(builder.module.gates.keys),
            updated: &updated
        )

        // check module is well formed
        try builder.module.check()

        let gates = builder.module.gates

        // check ports are intact
        #expect(gates.count == 7)
        #expect(gates.keys.contains(i1))
        #expect(gates.keys.contains(i2))
        #expect(gates.keys.contains(i3))
        #expect(gates.keys.contains(o1))
        #expect(gates.keys.contains(x1))

        // check XOR is driven by a third gate (constant value)
        let xnor = gates[x1]!
        #expect(xnor.srcs.count == 1)
        #expect(xnor.type == .logic(type: .nor))
        let constId = xnor.srcs.first!
        #expect(constId != g1)
        #expect(constId != g2)

        // check constant input is actually a constant
        let const = gates[constId]!
        #expect(const.srcs.count == 0)

        // check live list is properly updated
        #expect(updated.contains(i1))
        #expect(updated.contains(i2))
        #expect(updated.contains(i3))
    }
}
