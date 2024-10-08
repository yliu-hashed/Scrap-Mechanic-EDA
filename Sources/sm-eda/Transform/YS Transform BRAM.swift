//
//  YS Transform BRAM.swift
//  Scrap Mechanic EDA
//

import SMEDANetlist

func checkBRAMTimer(
    name: String, cell: borrowing YSCell, length: Int,
    updating outputLUTs: inout [UInt64: TransformOutputStore]
) throws {
    var names = Set(cell.conns.keys)

    func checkAndRemove(_ name: String, length: Int = 1) throws {
        guard names.contains(name) else {
            throw TransformError.malformedCellPorts(cellName: name, description: "Port `\(name)` cannot be found.")
        }
        guard cell.conns[name]?.count == length else {
            throw TransformError.malformedCellPorts(cellName: name, description: "Port `\(name)` has the wrong number of bits.")
        }
        names.remove(name)
    }

    // check clock
    try checkAndRemove("CLK1")

    // check write port
    try checkAndRemove("A1ADDR", length: length)
    try checkAndRemove("A1DATA")
    try checkAndRemove("A1EN")

    // check all read data has read address
    let readDataPattern = #/B([0-9]+)DATA/#
    for (portName, bits) in cell.conns {
        guard let match = try? readDataPattern.wholeMatch(in: portName) else { continue }
        let index = Int(match.1)!
        let addrName = "B\(index)ADDR"
        guard names.contains(addrName) else {
            throw TransformError.malformedCellPorts(cellName: name, description: "Address `\(addrName)` of read port `\(index)` cannot be found.")
        }
        try checkAndRemove(portName)
        // add read data to output table
        let outputStore = TransformOutputStore(nodeName: name, connName: portName, bitIndex: 0)
        guard case .shared(let id) = bits[0] else { fatalError() }
        outputLUTs.updateValue(outputStore, forKey: id)
    }

    // check read port addresses width
    let readAddrPattern = #/B([0-9]+)ADDR/#
    for portName in cell.conns.keys {
        guard let _ = try? readAddrPattern.wholeMatch(in: portName) else { continue }
        try checkAndRemove(portName, length: length)
    }

    guard names.isEmpty else {
        throw TransformError.malformedCellPorts(cellName: name, description: "Unknown ports provided \(names).")
    }
}

func emitBRAMTimer(builder: SMNetBuilder, length: Int, context: borrowing YSCell, cache: BRAMTimerCache) -> BRAMTimerTarget {
    let writeAddr: [YSBit] = context.conns["A1ADDR"]!

    let regex = #/([A-Z]+)([0-9]+)([A-Z]+)/#
    var readCount: Int = 0
    var validRead: Set<Int> = []
    var readPortShareWriteAddr: Set<Int> = []

    for (portName, bits) in context.conns {
        guard let match = try? regex.wholeMatch(in: portName),
              match.1 == "B"
        else { continue }

        let index = Int(match.2)! - 1

        readCount = max(readCount, index + 1)
        if match.3 == "ADDR", bits == writeAddr {
            readPortShareWriteAddr.insert(index)
        }
        if match.3 == "DATA" {
            validRead.insert(index)
        }
    }

    // form gen ports
    let indepWrite = readPortShareWriteAddr.isEmpty
    let indepReadCount = validRead.count - readPortShareWriteAddr.count
    var ports: [BRAMPortConfig] = [indepWrite ? .writeOnly : .readWrite]
    for _ in 0..<indepReadCount { ports.append(.readOnly) }

    // generate bram
    let config = BRAMTimerConfig(
        addressability: 1,
        addressSpacePow2: length,
        multiplexityPow2: 0,
        ports: ports
    )

    let bram = genBRAMTimer(config: config, into: builder)

    // map port
    var readPorts: [BRAMTimerTarget.ReadPort?] = []
    var used: Int = 1
    for i in 0..<readCount {
        // no read use this port, skip
        guard validRead.contains(i) else {
            readPorts.append(nil)
            continue
        }
        let mapIndex: Int
        if readPortShareWriteAddr.contains(i) {
            // real read, but share write address, map to write port
            mapIndex = 0
        } else {
            // real independent read, assign unique read port
            mapIndex = used
            used += 1
        }

        let port = BRAMTimerTarget.ReadPort(
            data: bram.ports[mapIndex].readData[0],
            addr: bram.ports[mapIndex].address
        )
        readPorts.append(port)
    }

    return BRAMTimerTarget(
        clk: bram.clk,
        writeEnable: bram.ports[0].writeEnable,
        data: bram.ports[0].writeData[0],
        addr: bram.ports[0].address,
        readPorts: readPorts
    )
}

struct BRAMTimerTarget: CellLowerTarget {
    var clk: UInt64
    var writeEnable: UInt64
    var data: UInt64
    var addr: [UInt64]
    var readPorts: [ReadPort?]

    struct ReadPort {
        var data: UInt64
        var addr: [UInt64]
    }

    func gateFor(port: String, bit: Int) -> [UInt64] {
        // write ports and clock
        switch port {
            case "CLK1":
                return [clk]
            case "A1ADDR":
                return [addr[bit]]
            case "A1DATA":
                return [data]
            case "A1EN":
                return [writeEnable]
            default:
                break
        }
        // read ports
        let regex = #/B([0-9]+)([A-Z]+)/#
        let match = try! regex.wholeMatch(in: port)!
        let index = Int(match.1)! - 1
        let port = readPorts[index]
        if match.2 == "ADDR" {
            guard let addr = port?.addr else { return [] }
            return [addr[bit]]
        } else {
            return [port!.data]
        }
    }
}
