//
//  YS Transform.swift
//  Scrap Mechanic EDA
//

import SMEDANetlist

struct TransformTable {
    struct InputPort {
        var name: String
        var bit: Int
    }

    struct Output {
        var cell: String
        var port: String
        var bit: Int
    }

    var inputPorts: [UInt64: InputPort] = [:]
    var outputs: [UInt64: Output] = [:]
    var cellTypes: [String: YSSMCellType] = [:]

    init(byChecking ysModule: borrowing YSModule) throws {
        // Generate input port lut
        for (portName, port) in ysModule.ports where port.direction == .input {
            for (index, bit) in port.bits.enumerated() {
                guard case .shared(let connId) = bit else {
                    fatalError("Input \"\(portName)\" contains fixed state.")
                }
                let store = TransformTable.InputPort(name: portName, bit: index)
                inputPorts.updateValue(store, forKey: connId)
            }
        }

        cellTypes.reserveCapacity(ysModule.cells.count)

        for (cellName, cell) in ysModule.cells {
            guard let cellType = extractType(typeName: cell.type) else {
                throw TransformError.invalidCellType(cellName: cellName, cellTypeName: cell.type)
            }

            cellTypes.updateValue(cellType, forKey: cellName)

            switch cellType {
            case .basicGate(_, let size):
                if let sureSize = size {
                    // a basic gate with known size
                    guard cell.conns.count == sureSize + 1,
                          cell.conns.allSatisfy({ $0.value.count == 1 }),
                          let outputBits = cell.conns.first(where: { $0.key == "Y" })?.value,
                          outputBits.count == 1,
                          case .shared(let id) = outputBits[0] else {

                        throw TransformError.malformedCellPorts(cellName: cellName)
                    }
                    guard !outputs.keys.contains(id) else {
                        throw TransformError.duplicateOutput(
                            connId: id, cellName1: cellName,
                            cellName2: outputs[id]!.cell
                        )
                    }
                    let outputStore = TransformTable.Output(cell: cellName, port: "Y", bit: 0)
                    outputs.updateValue(outputStore, forKey: id)
                } else {
                    // a basic gate with variable size
                    guard cell.conns.count == 2,
                          let inputBits = cell.conns["A"],
                          inputBits.count >= 1,
                          let outputBits = cell.conns["Y"],
                          outputBits.count == 1,
                          case .shared(let id) = outputBits[0] else {
                        throw TransformError.malformedCellPorts(cellName: cellName)
                    }
                    guard !outputs.keys.contains(id) else {
                        throw TransformError.duplicateOutput(
                            connId: id, cellName1: cellName,
                            cellName2: outputs[id]!.cell
                        )
                    }
                    let outputStore = TransformTable.Output(cell: cellName, port: "Y", bit: 0)
                    outputs.updateValue(outputStore, forKey: id)
                }
            case .psudoDFF(hasAsyncReset: false):
                try checkDFF(name: cellName, cell: cell, updating: &outputs)
            case .psudoDFF(hasAsyncReset: true):
                try checkDFFWithAsyncReset(name: cellName, cell: cell, updating: &outputs)
            case .psudoBRAMTimer(let length):
                try checkBRAMTimer(name: cellName, cell: cell, length: length, updating: &outputs)
            }
        }
    }
}

/// Create all input and output gates.
fileprivate func createPorts(
    from ysModule: borrowing YSModule,
    into builder: SMNetBuilder,
    constHigh: UInt64,
    using table: borrowing TransformTable
) throws -> [String: [UInt64]] {
    var portTargets: [String: [UInt64]] = [:]
    for (portName, port) in ysModule.ports {
        var bitsTarget = [UInt64](repeating: 0, count: port.bits.count)

        if port.direction == .output,
           port.bits.allSatisfy({ $0 == .fixed(state: false) }) {
            print("Output port \(portName) is stripped, it is constant zero")
            continue
        }

        for (index, bit) in port.bits.enumerated() {
            let gate: UInt64
            // const driver for output gate
            if port.direction == .output, case .fixed(let state) = bit, state == true {
                gate = builder.addLogic(type: .nor)
                builder.connect(constHigh, to: gate)
            } else {
                gate = builder.addLogic(type: .or)
            }
            // output gate
            bitsTarget[index] = gate
        }
        portTargets.updateValue(bitsTarget, forKey: portName)
        // register
        let direction = port.direction
        switch direction {
        case .input:
            builder.registerInputGates(port: portName, gates: bitsTarget)
        case .output:
            builder.registerOutputGates(port: portName, gates: bitsTarget)
        }
    }
    return portTargets
}

/// transform cells into gates and store them as lowered target
fileprivate func lowerCells(
    from ysModule: borrowing YSModule,
    into builder: SMNetBuilder,
    constLow: UInt64,
    constHigh: UInt64,
    using table: borrowing TransformTable
) throws -> [String: any LoweredCell] {
    let cache = LoweringCache(builder: builder)
    var targets: [String: any LoweredCell] = [:]
    for (cellName, cell) in ysModule.cells {
        let cellType = table.cellTypes[cellName]!
        // lower specific targets
        let loweredTarget = lowerCell(cellType: cellType, builder: builder, context: cell, cache: cache)

        // lower constant driver
        for (portName, bits) in cell.conns where cellType.isInput(name: portName) {
            for (index, bit) in bits.enumerated() {
                guard case .fixed(let state) = bit else { continue }
                let inputGates = loweredTarget.gateFor(port: portName, bit: index)
                if inputGates.isEmpty { continue }
                let driver = state ? constHigh : constLow
                builder.connect(driver, to: inputGates)
            }
        }
        targets.updateValue(loweredTarget, forKey: cellName)
    }
    return targets
}

fileprivate func connectCellsAndOutputs(
    from ysModule: borrowing YSModule,
    into builder: SMNetBuilder,
    constLow: UInt64,
    constHigh: UInt64,
    cells: borrowing [String: any LoweredCell],
    ports: borrowing [String: [UInt64]],
    using table: borrowing TransformTable
) throws {
    func getOutputGate(connId: UInt64) throws -> UInt64 {
        if let source = table.outputs[connId] { // if source is another cell
            let lowered = cells[source.cell]!
            let out = lowered.gateFor(port: source.port, bit: source.bit)
            assert(out.count == 1)
            return out[0]
        } else if let source = table.inputPorts[connId] { // if source is a input port
            let portTarget = ports[source.name]!
            return portTarget[source.bit]
        }

        throw TransformError.connectionDoesNotExist(connId: connId)
    }

    // connect all internal gates (between cells) by referencing output lut and target
    for (cellName, cell) in ysModule.cells {
        let cellType = table.cellTypes[cellName]!
        let lowered = cells[cellName]!
        for (port, bits) in cell.conns where cellType.isInput(name: port) {
            for (bitIndex, bit) in bits.enumerated() {
                guard case .shared(let connId) = bit else { continue }

                let srcNodeId = try getOutputGate(connId: connId)
                let dstNodeIds = lowered.gateFor(port: port, bit: bitIndex)

                builder.connect(srcNodeId, to: dstNodeIds)
            }
        }
    }

    // connect output port
    for (portName, port) in ysModule.ports {
        guard port.direction == .output,
              let portTarget = ports[portName]
        else { continue }

        for (index, bit) in port.bits.enumerated() {
            guard case .shared(let id) = bit else { continue }
            let source = try getOutputGate(connId: id)

            builder.connect(source, to: portTarget[index])
        }
    }
}

/// strip input with no connections
fileprivate func stripUnusedInputs(_ builder: SMNetBuilder) {
    let inputNames: [String] = [String](builder.module.inputs.keys)
    for inputName in inputNames {
        let gates = builder.module.inputs[inputName]!.gates
        if gates.allSatisfy({ builder.module.gates[$0]!.dsts.isEmpty }) {
            builder.unregisterInputGates(port: inputName)
            for gate in gates {
                builder.removeGate(gate)
            }
            print("Input port \(inputName) is stripped, it has no connections")
        }
    }
}

fileprivate func inferAndMarkClockDomain(
    in module: inout SMModule,
    forceClockInputs: [String],
    cells: borrowing [String: any LoweredCell]
) throws {
    let hasSequential = module.gates.contains { $0.value.isSequential }
    if hasSequential {
        var clocks: [String] = forceClockInputs
        if clocks.isEmpty {
            print("Warning: Input contains sequential cells, but no clock domain is specified.")
            let commonNames: Set<String> = ["clock", "clk"]
            let makeshiftClock = module.inputs.keys.first { commonNames.contains($0.lowercased()) }
            if let makeshiftClock = makeshiftClock {
                clocks = [makeshiftClock]
                print("   Input \"\(makeshiftClock)\" will be considered a clock.")
            } else {
                print("   Net will be generated without a clock.")
            }
            print("   Indicate a clock domain using the '--clk <clock>' argument.\n")
        }

        for clock in clocks {
            guard let gates = module.inputs[clock]?.gates else {
                print("Warning: specified clock domain \(clock) is either doesn't exist or optimizeed away.")
                print("   Generation will continue without it.\n")
                continue
            }
            guard gates.count == 1 else {
                throw ModuleSelectionError.clockIsBus(name: clock)
            }
            module.inputs[clock]!.isClock = true
            // mark and check clock tree
            var frontier: [UInt64] = [gates.first!]
            while let gateId = frontier.popLast() {
                let gate = module.gates[gateId]!
                if gate.isSequential { continue }
                guard gate.srcs.count <= 1 else {
                    throw ModuleSelectionError.clockHasLogic(name: clock)
                }
                module.gates[gateId]!.domain = .clockTree
                frontier.append(contentsOf: gate.dsts)
            }
        }
    }
}

fileprivate func printLoweredCellStats(
    cells: borrowing [String: any LoweredCell]
) {
    var table: [String: Int] = [:]
    for cell in cells.lazy {
        let name = cell.value.name
        if table.keys.contains(name) {
            table[name]! += 1
        } else {
            table[name] = 1
        }
    }

    let flat = table
        .sorted(by: { $0.value > $1.value })
        .map ({ (key: $0, value: String($1)) })
    printItems(title: "Transformed", flat, numbered: true)
}

func transform(
    ysModule: YSModule,
    moduleName: String,
    forceClockInputs: [String],
    verbose: Bool
) throws -> SMModule {

    let table = try TransformTable(byChecking: ysModule)

    let builder = SMNetBuilder()
    builder.setName(name: moduleName)

    // create const drivers
    let constLow: UInt64 = builder.addLogic(type: .or)
    let constHigh: UInt64 = builder.addLogic(type: .nor)
    builder.connect(constLow, to: constHigh)

    let loweredPorts = try createPorts(
        from: ysModule, into: builder,
        constHigh: constHigh,
        using: table
    )

    let loweredCells = try lowerCells(
        from: ysModule, into: builder,
        constLow: constLow, constHigh: constHigh,
        using: table
    )

    if verbose {
        printLoweredCellStats(cells: loweredCells)
    }

    try connectCellsAndOutputs(
        from: ysModule,
        into: builder,
        constLow: constLow, constHigh: constHigh,
        cells: loweredCells,
        ports: loweredPorts,
        using: table
    )

    stripUnusedInputs(builder)

    builder.legalize()

    var module = builder.module

    transferAttributes(ysModule: ysModule, to: &module)

    try inferAndMarkClockDomain(
        in: &module,
        forceClockInputs: forceClockInputs,
        cells: loweredCells
    )

    return module
}

// MARK: Lower Cell
class LoweringCache {
    var timerCache: BRAMTimerCache

    init(builder: SMNetBuilder) {
        timerCache = BRAMTimerCache(builder: builder)
    }
}

private func lowerCell(cellType: YSSMCellType, builder: SMNetBuilder, context: borrowing YSCell, cache: LoweringCache) -> any LoweredCell {
    switch cellType {
    case .basicGate(let type, _):
        let mainGate = builder.addLogic(type: type)
        return LoweredLogic(type: type, gateId: mainGate)

    case .psudoDFF(hasAsyncReset: false):
        return emitDFF(builder: builder)

    case .psudoDFF(hasAsyncReset: true):
        return emitDFFWithAsyncReset(builder: builder)

    case .psudoBRAMTimer(let length):
        return emitBRAMTimer(builder: builder, length: length, context: context, cache: cache.timerCache)
    }
}

// MARK: Internal Types
protocol LoweredCell {
    var name: String { get }
    func gateFor(port: String, bit: Int) -> [UInt64]
    func isClock(port: String) -> Bool
}

struct LoweredLogic: LoweredCell {
    var type: SMLogicType
    var gateId: UInt64

    var name: String { type.name }
    func gateFor(port: String, bit: Int) -> [UInt64] {
        return [gateId]
    }
    func isClock(port: String) -> Bool {
        return false
    }
}

// MARK: Utility
func extractType(typeName: String) -> YSSMCellType? {
    let tokens = typeName.split(separator: "_")
    if tokens.first == "SM", tokens.count > 1 {
        if tokens[1] == "PSUDO", tokens.count > 2 {
            // is psudo
            if tokens.count == 3, tokens[2] == "DFFE" {
                return .psudoDFF(hasAsyncReset: false)
            }
            if tokens.count == 3, tokens[2] == "DFFER" {
                return .psudoDFF(hasAsyncReset: true)
            }
            if tokens.count == 5, tokens[2] == "BRAM",
               tokens[3] == "TIMER", let len = Int(tokens[4]) {
                return .psudoBRAMTimer(length: len)
            }
        } else if tokens.count >= 2 {
            if tokens.count == 3,
               let gateType = SMLogicType(name: tokens[1]),
               let size = Int(tokens[2]) {

                return .basicGate(type: gateType, size: size)
            }
            if tokens.count == 2,
               let gateType = SMLogicType(name: tokens[1]) {
                return .basicGate(type: gateType, size: nil)
            }
        }
    }
    return nil
}

extension SMLogicType: CustomStringConvertible {
    init?(name: Substring) {
        switch name {
        case "OR":   self = .or
        case "AND":  self = .and
        case "NOR":  self = .nor
        case "NAND": self = .nand
        case "XOR":  self = .xor
        case "XNOR": self = .xnor
        default:
            return nil
        }
    }

    var name: String {
        switch self {
        case .or:   return "OR"
        case .and:  return "AND"
        case .nor:  return "NOR"
        case .nand: return "NAND"
        case .xor:  return "XOR"
        case .xnor: return "XNOR"
        }
    }

    public var description: String { name }
}
