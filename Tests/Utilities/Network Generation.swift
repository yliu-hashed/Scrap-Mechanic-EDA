//
//  Network Generation.swift
//  Scrap Mechanic EDA
//

import SMEDANetlist

/// Build a simple ripple carry adder for testing purposes.
///
/// The port names are guarenteed to be named as follows.
/// - `c_in`: Carry input.
/// - `a_in`: Argument 1 of `width` wide.
/// - `b_in`: Argument 2 of `width` wide.
/// - `y_out`: Sum output of `width` wide.
/// - `c_out`: Carry output.
///
/// The gate IDs are guarenteed to be ordered numerically consistently with the
/// following increasing order:
///
/// `c_in`, `a_in[0]`, `b_in[0]`, `y_out[0]`, `a_in[1]`, `b_in[1]`, `y_out[1]`, ..., `c_out`.
///
/// The functions of other gate IDs cannot be guarenteed.
///
func buildSimpleRippleAdder(width: Int) -> SMModule {
    let builder = SMNetBuilder()
    builder.setName(name: "test adder \(width)")
    var carry = builder.addLogic(type: .or)
    builder.registerInputGates(port: "c_in", gates: [carry])

    var inputAs: [UInt64] = []
    var inputBs: [UInt64] = []
    var outputs: [UInt64] = []

    func buildHalfAdder(a: UInt64, b: UInt64) -> (y: UInt64, c: UInt64) {
        let y = builder.addLogic(type: .xor)
        builder.connect([a, b], to: y)
        let c = builder.addLogic(type: .and)
        builder.connect([a, b], to: c)
        return (y: y, c: c)
    }

    for _ in 0..<width {
        let inputA = builder.addLogic(type: .or)
        let inputB = builder.addLogic(type: .or)
        inputAs.append(inputA)
        inputBs.append(inputB)
        let partial = buildHalfAdder(a: inputA, b: inputB)
        let full = buildHalfAdder(a: partial.y, b: carry)
        carry = builder.addLogic(type: .or)
        builder.connect([partial.c, full.c], to: carry)
        let output = builder.addLogic(type: .or)
        outputs.append(output)
        builder.connect(full.y, to: output)
    }

    builder.registerInputGates(port: "a_in", gates: inputAs)
    builder.registerInputGates(port: "b_in", gates: inputBs)
    builder.registerOutputGates(port: "y_out", gates: outputs)
    builder.registerOutputGates(port: "c_out", gates: [carry])

    return builder.module
}

struct RandomNetworkConfig {
    var internalGateCount: Int
    var inputCount: Int
    var outputCount: Int

    var minFaninLimit: Int = 0
    var maxFaninLimit: Int = 10

    var maxFanoutLimit: Int = 10

    /// Shorter produces more "linear" network
    var activeWindow: Int = 71
}

func buildRandomNetwork(seed: UInt64, config: RandomNetworkConfig) -> SMModule {
    var random = SimpleRandomGenerator(seed: seed)

    let builder = SMNetBuilder()
    builder.setName(name: "Random \(seed)")

    var list: [UInt64] = []

    // build inputs
    for _ in 0..<config.inputCount {
        list.append(builder.addLogic(type: .or))
    }
    builder.registerInputGates(port: "in", gates: list)

    // build body
    func newGate() -> UInt64 {
        let logicType = SMLogicType.allCases.randomElement(using: &random)!
        let gateId = builder.addLogic(type: logicType)

        let faninRange = config.minFaninLimit...config.maxFaninLimit
        let faninCount = faninRange.randomElement(using: &random)!

        for _ in 0..<faninCount {
            let srcId = list.suffix(config.activeWindow).randomElement(using: &random)!
            let src = builder.module.gates[srcId]!
            if src.dsts.count >= config.maxFanoutLimit { continue }
            builder.connect(srcId, to: gateId)
        }
        return gateId
    }

    for _ in 0..<max(config.internalGateCount, config.outputCount) {
        list.append(newGate())
    }
    // build output
    var outputs: [UInt64] = []
    for _ in 0..<config.outputCount {
        outputs.append(newGate())
    }
    builder.registerOutputGates(port: "out", gates: outputs)

    return builder.module
}
