//
//  BRAM Timer Write Port.swift
//  Scrap Mechanic EDA
//

public struct BRAMTimerPortInfo {
    public var address: [UInt64]
    public var readData: [UInt64]! = nil
    public var writeData: [UInt64]! = nil
    public var writeEnable: UInt64! = nil
}

public struct BRAMTimerPortsInfo {
    public var clk: UInt64
    var clkPulse: UInt64
    public var ports: [BRAMTimerPortInfo]
}

func genBRAMTimerPorts(config: borrowing BRAMTimerConfig, builder: SMNetBuilder, global: Bool) -> BRAMTimerPortsInfo {

    let clk = builder.addLogic(type: .and)
    if global { builder.registerInputGates(port: "CLK", gates: [clk]) }
    // build clock edge
    let clkNeg = builder.addLogic(type: .nand)
    let clkPulse = builder.addLogic(type: .and)
    builder.connect(chain: clk, clkNeg, clkPulse)
    builder.connect(clk, to: clkPulse)

    var portInfos: [BRAMTimerPortInfo] = []
    portInfos.reserveCapacity(config.ports.count)

    for i in config.ports.indices {
        let info = genBRAMTimerPort(config: config, builder: builder, index: i, global: global)
        portInfos.append(info)
    }

    return BRAMTimerPortsInfo(clk: clk, clkPulse: clkPulse, ports: portInfos)
}

func genBRAMTimerPort(config: borrowing BRAMTimerConfig, builder: SMNetBuilder, index: Int, global: Bool) -> BRAMTimerPortInfo {

    var address = [UInt64](repeating: 0, count: config.addressSpacePow2)
    for i in 0..<config.addressSpacePow2 {
        address[i] = builder.addLogic(type: .and, keepTiming: false)
    }
    if global {
        builder.registerInputGates(port: "\(index)ADDR", gates: address)
    }

    var info = BRAMTimerPortInfo(address: address)

    if (config.ports[index].hasRead) {
        var data = [UInt64](repeating: 0, count: config.addressability)
        for i in 0..<config.addressability {
            data[i] = builder.addLogic(type: .or, keepTiming: false)
        }
        info.readData = data
        if global {
            builder.registerOutputGates(port: "\(index)DATAO", gates: data)
        }
    }

    if (config.ports[index].hasWrite) {
        var data = [UInt64](repeating: 0, count: config.addressability)
        for i in 0..<config.addressability {
            data[i] = builder.addLogic(type: .and, keepTiming: false)
        }
        info.writeData = data
        if global {
            builder.registerInputGates(port: "\(index)DATAI", gates: data)
        }

        info.writeEnable = builder.addLogic(type: .and, keepTiming: false)
        if global {
            builder.registerInputGates(port: "\(index)WE", gates: [info.writeEnable])
        }
    }

    return info
}
