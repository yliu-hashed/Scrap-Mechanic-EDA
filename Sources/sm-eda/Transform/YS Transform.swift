//
//  YS Transform.swift
//  Scrap Mechanic EDA
//

import SMEDANetlist

func transform(ysModule: YSModule, moduleName: String, clockDomainNames: [String], verbose: Bool) throws -> SMModule {

    // Record keeping for statistics display
    var transformRecord: [String: Int] = [:]
    func recordTransform(for name: String) {
        if let oldAmount = transformRecord[name] {
            transformRecord[name] = oldAmount + 1
        } else {
            transformRecord[name] = 1
        }
    }

    // generate input port lut
    var inputPortLUTs: [UInt64: InputPortStore] = [:]
    for (portName, port) in ysModule.ports where port.direction == .input {
        for (index, bit) in port.bits.enumerated() {
            guard case .shared(let connId) = bit else {
                fatalError("Input \"\(portName)\" contains fixed state.")
            }
            let store = InputPortStore(portName: portName, bitIndex: index)
            inputPortLUTs.updateValue(store, forKey: connId)
        }
    }

    // make sure all cell types are supported
    // check if connections are all valid
    // generate lookup table of cell type and output
    var outputLUTs: [UInt64: TransformOutputStore] = [:]
    var cellTypeLUTs: [String: YSSMCellType] = [:]
    cellTypeLUTs.reserveCapacity(ysModule.cells.count)

    for (cellName, cell) in ysModule.cells {
        guard let cellType = extractType(typeName: cell.type) else {
            throw TransformError.invalidCellType(cellName: cellName, cellTypeName: cell.type)
        }

        cellTypeLUTs.updateValue(cellType, forKey: cellName)

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
                    guard !outputLUTs.keys.contains(id) else {
                        throw TransformError.duplicateOutput(
                            connId: id, cellName1: cellName,
                            cellName2: outputLUTs[id]!.nodeName
                        )
                    }
                    let outputStore = TransformOutputStore(nodeName: cellName, connName: "Y", bitIndex: 0)
                    outputLUTs.updateValue(outputStore, forKey: id)
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
                    guard !outputLUTs.keys.contains(id) else {
                        throw TransformError.duplicateOutput(
                            connId: id, cellName1: cellName,
                            cellName2: outputLUTs[id]!.nodeName
                        )
                    }
                    let outputStore = TransformOutputStore(nodeName: cellName, connName: "Y", bitIndex: 0)
                    outputLUTs.updateValue(outputStore, forKey: id)
                }
            case .psudoDFF(hasAsyncReset: false):
                try checkDFF(name: cellName, cell: cell, updating: &outputLUTs)
            case .psudoDFF(hasAsyncReset: true):
                try checkDFFWithAsyncReset(name: cellName, cell: cell, updating: &outputLUTs)
            case .psudoBRAMTimer(let length):
                try checkBRAMTimer(name: cellName, cell: cell, length: length, updating: &outputLUTs)
        }
    }

    let builder = SMNetBuilder()
    builder.setName(name: moduleName)

    // const driver emit function
    var constDangler: UInt64? = nil
    var constHighDangler: UInt64? = nil

    func getConstDriver(state: Bool) -> UInt64 {
        recordTransform(for: "Constant Driver")
        if state { // high
            if constHighDangler == nil {
                let lowDangler = getConstDriver(state: false)
                constHighDangler = builder.addLogic(type: .nor)
                builder.connect(lowDangler, to: constHighDangler!)
            }
            return constHighDangler!
        } else { // low
            if constDangler == nil { constDangler = builder.addLogic(type: .or) }
            return constDangler!
        }
    }

    // create all input & output gates
    var portTargets: [String: [UInt64]] = [:]
    for (portName, port) in ysModule.ports {
        var bitsTarget = [UInt64](repeating: 0, count: port.bits.count)

        if port.direction == .output,
           port.bits.allSatisfy({ bit in
               if case .fixed(false) = bit {
                   return true
               }
               return false
           }) {
            print("Output port \(portName) is stripped, it is constant zero")
            continue
        }

        for (index, bit) in port.bits.enumerated() {
            let gate: UInt64
            // const driver for output gate
            if port.direction == .output, case .fixed(let state) = bit, state {
                let constLow = getConstDriver(state: false)
                gate = builder.addLogic(type: .nor)
                builder.connect(constLow, to: gate)
            } else {
                gate = builder.addLogic(type: .or)
            }
            // output gate
            bitsTarget[index] = gate
            recordTransform(for: "Port")
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

    // transform cells into gates and store them as lower target
    let cache = LoweringCache(builder: builder)
    var lowerTargets: [String: any CellLowerTarget] = [:]
    for (cellName, cell) in ysModule.cells {
        let cellType = cellTypeLUTs[cellName]!
        // lower specific targets
        let lowerTarget = lowerCell(cellType: cellType, builder: builder, context: cell, cache: cache)
        recordTransform(for: cellType.name)

        // lower constant driver
        for (portName, bits) in cell.conns where cellType.isInput(name: portName) {
            for (index, bit) in bits.enumerated() {
                guard case .fixed(let state) = bit else { continue }
                let inputGates = lowerTarget.gateFor(port: portName, bit: index)
                if inputGates.isEmpty { continue }
                let driver = getConstDriver(state: state)
                builder.connect(driver, to: inputGates)
            }
        }

        lowerTargets.updateValue(lowerTarget, forKey: cellName)
    }

    func getOutputGate(connId: UInt64) throws -> UInt64 {
        if let source = outputLUTs[connId] { // if source is another cell
            let lowerTarget = lowerTargets[source.nodeName]!
            let out = lowerTarget.gateFor(port: source.connName, bit: source.bitIndex)
            assert(out.count == 1)
            return out[0]
        } else if let source = inputPortLUTs[connId] { // if source is a input port
            let portTarget = portTargets[source.portName]!
            return portTarget[source.bitIndex]
        }

        throw TransformError.connectionDoesNotExist(connId: connId)
    }

    // connect all internal gates (between cells) by referencing output lut and target
    for (cellName, cell) in ysModule.cells {
        let cellType = cellTypeLUTs[cellName]!
        let lowerTarget = lowerTargets[cellName]!
        for (port, bits) in cell.conns where cellType.isInput(name: port) {
            for (bitIndex, bit) in bits.enumerated() {
                guard case .shared(let connId) = bit else { continue }

                let srcNodeId = try getOutputGate(connId: connId)
                let dstNodeId = lowerTarget.gateFor(port: port, bit: bitIndex)

                builder.connect(srcNodeId, to: dstNodeId)
            }
        }
    }

    // connect output port
    for (portName, port) in ysModule.ports {
        guard port.direction == .output,
              let portTarget = portTargets[portName]
        else { continue }

        for (index, bit) in port.bits.enumerated() {
            guard case .shared(let id) = bit else { continue }
            let source = try getOutputGate(connId: id)

            builder.connect(source, to: portTarget[index])
        }
    }

    // strip input with no connections
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

    builder.legalize()

    if verbose {
        printTransformationStats(transformRecord)
    }

    var module = builder.module

    transferAttributes(ysModule: ysModule, to: &module)

    // identify & annotate clock domains
    if !module.sequentialNodes.isEmpty {
        var trueClockDomainNames: [String] = clockDomainNames
        if clockDomainNames.isEmpty {
            print("Warning: Input contains sequential cells, but no clock domain is specified.")
            let commonNames: Set<String> = ["clock", "clk"]
            let makeshiftClock = module.inputs.keys.first { commonNames.contains($0.lowercased()) }
            if let makeshiftClock = makeshiftClock {
                trueClockDomainNames = [makeshiftClock]
                print("   Input \"\(makeshiftClock)\" will be considered a clock.")
            } else {
                print("   Net will be generated without a clock.")
            }
            print("   Indicate a clock domain using the '--clk <clock>' argument.\n")
        }

        for clockDomainName in trueClockDomainNames {
            guard let gates = module.inputs[clockDomainName]?.gates else {
                print("Warning: specified clock domain \(clockDomainName) is either doesn't exist or optimizeed away.")
                print("   Generation will continue without it.\n")
                continue
            }
            guard gates.count == 1 else {
                throw ModuleSelectionError.malformedClockDomain(name: clockDomainName)
            }
            module.inputs[clockDomainName]!.isClock = true
        }
    }

    return module
}

// MARK: Lower Cell
class LoweringCache {
    var timerCache: BRAMTimerCache

    init(builder: SMNetBuilder) {
        timerCache = BRAMTimerCache(builder: builder)
    }
}

private func lowerCell(cellType: YSSMCellType, builder: SMNetBuilder, context: borrowing YSCell, cache: LoweringCache) -> any CellLowerTarget {
    switch cellType {
        case .basicGate(let type, _):
            let mainGate = builder.addLogic(type: type)
            return LogicLowerTarget(gateId: mainGate)

        case .psudoDFF(hasAsyncReset: false):
            return emitDFF(builder: builder)

        case .psudoDFF(hasAsyncReset: true):
            return emitDFFWithAsyncReset(builder: builder)

        case .psudoBRAMTimer(let length):
            return emitBRAMTimer(builder: builder, length: length, context: context, cache: cache.timerCache)
    }
}

// MARK: Internal Types
protocol CellLowerTarget {
    func gateFor(port: String, bit: Int) -> [UInt64]
}

struct LogicLowerTarget: CellLowerTarget {
    var gateId: UInt64
    func gateFor(port: String, bit: Int) -> [UInt64] {
        return [gateId]
    }
}

struct TransformOutputStore {
    var nodeName: String
    var connName: String
    var bitIndex: Int
}

private struct InputPortStore {
    var portName: String
    var bitIndex: Int
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
