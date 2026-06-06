//
//  Algebraic Const Fold.swift
//  Scrap Mechanic EDA
//

import Testing

@testable import SMEDANetlist

struct AlgebraicConstFoldTests {

    @Test("Fold const false into OR")
    func testFoldFalseToOR() throws {
        let builder = SMNetBuilder()
        let i1 = builder.addLogic(type: .or)
        let c1 = builder.addLogic(type: .or)
        let c2 = builder.addLogic(type: .or)
        let o1 = builder.addLogic(type: .or)
        builder.connect(chain: i1, o1)
        builder.connect(chain: c1, c2, o1)
        builder.registerInputGates(port: "in", gates: [i1])
        builder.registerOutputGates(port: "out", gates: [o1])

        // test behavior
        var updated: Set<UInt64> = []
        algebraicConstFold(
            builder: builder,
            updated: &updated
        )

        // check module is well formed
        try builder.module.check()

        // check gate is reduced
        #expect(builder.module.gates[o1]?.srcs == [i1])
        #expect(builder.module.gates[o1]?.dsts == [])
        #expect(builder.module.gates[i1]?.srcs == [])
        #expect(builder.module.gates[i1]?.dsts == [o1])

        // check deleted nodes are properly deleted
        #expect(builder.module.gates[c1] == nil)
        #expect(builder.module.gates[c2] == nil)

        // check updated list contains input and output
        #expect(!updated.contains(i1))
        #expect(updated.contains(o1))
    }

    @Test("Fold const true into OR")
    func testFoldTrueToOR() throws {
        let builder = SMNetBuilder()
        let i1 = builder.addLogic(type: .or)
        let c1 = builder.addLogic(type: .or)
        let c2 = builder.addLogic(type: .nor)
        let o1 = builder.addLogic(type: .or)
        builder.connect(chain: i1, o1)
        builder.connect(chain: c1, c2, o1)
        builder.registerInputGates(port: "in", gates: [i1])
        builder.registerOutputGates(port: "out", gates: [o1])

        // test behavior
        var updated: Set<UInt64> = []
        algebraicConstFold(
            builder: builder,
            updated: &updated
        )

        // check module is well formed
        try builder.module.check()

        // check output is driven by constant false
        #expect(builder.module.gates[o1]?.srcs == [c2])
        #expect(builder.module.gates[o1]?.type == .logic(type: .or))

        #expect(builder.module.gates[c2]?.srcs == [c1])
        #expect(builder.module.gates[c2]?.type == .logic(type: .nor))

        #expect(builder.module.gates[c1]?.srcs == [])

        // check updated list
        #expect(updated.contains(i1))
        #expect(updated.contains(o1))
        #expect(!updated.contains(c1))
        #expect(!updated.contains(c2))
    }

    @Test("Fold const true into XOR")
    func testFoldTrueToXOR() throws {
        // build network of 8 long buffer chain
        let builder = SMNetBuilder()
        let i1 = builder.addLogic(type: .or)
        let c1 = builder.addLogic(type: .or)
        let c2 = builder.addLogic(type: .nor)
        let o1 = builder.addLogic(type: .xor)
        builder.connect(i1, to: o1)
        builder.connect(chain: c1, c2, o1)
        builder.registerInputGates(port: "in", gates: [i1])
        builder.registerOutputGates(port: "out", gates: [o1])

        // test behavior
        var updated: Set<UInt64> = []
        algebraicConstFold(
            builder: builder,
            updated: &updated
        )

        // check module is well formed
        try builder.module.check()

        // check output is good
        let gates = builder.module.gates
        let o1Gate = gates[o1]!
        #expect(o1Gate.type == .logic(type: .xnor))
        try #require(o1Gate.srcs.count == 1)
    }

}
