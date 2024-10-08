//
//  BRAM Timer.swift
//  Scrap Mechanic EDA
//

public struct BRAMTimerConfig{
    public let addressability: Int
    public let addressSpacePow2: Int
    public let multiplexityPow2: Int
    public let ports: [BRAMPortConfig]

    public var clockAddressSpacePow2: Int { addressSpacePow2 - multiplexityPow2 }
    public var multiplexity: Int { 1 << multiplexityPow2 }
    public var timerCycleLength: Int { 1 << clockAddressSpacePow2 }
    public var timerCycleLengthS: Float { Float(timerCycleLength) / 40 }

    public init(
        addressability: Int = 8,
        addressSpacePow2: Int,
        multiplexityPow2: Int,
        ports: [BRAMPortConfig] = [.readWrite]
    ) {
        self.addressability = addressability
        self.addressSpacePow2 = addressSpacePow2
        self.multiplexityPow2 = multiplexityPow2
        self.ports = ports
    }
}

@discardableResult
public func genBRAMTimer(config: borrowing BRAMTimerConfig, into builder: SMNetBuilder, global: Bool = false) -> BRAMTimerPortsInfo {

    assert(config.clockAddressSpacePow2 >= 2)
    assert(config.addressability > 0)

    let oldKeepTiming = builder.defaultKeepTiming
    builder.defaultKeepTiming = true

    let clock = genClock(config: config, builder: builder)
    let loopBank = genBRAMTimerLoopBank(config: config, builder: builder)
    let portInfo = genBRAMTimerPorts(config: config, builder: builder, global: global)
    for (i, port) in config.ports.enumerated() {
        let info = portInfo.ports[i]
        if port.hasRead {
            genReadPort(
                config: config, builder: builder, portInfo: info,
                clock: clock, loopBank: loopBank
            )
        }
        if port.hasWrite {
            genBRAMTimerWritePort(
                config: config, builder: builder, portInfo: info,
                clock: clock, loopBank: loopBank, clkPulse: portInfo.clkPulse
            )
        }
    }

    builder.defaultKeepTiming = oldKeepTiming
    return portInfo
}

public func genBRAMTimer(config: borrowing BRAMTimerConfig) -> SMModule {
    assert(config.clockAddressSpacePow2 >= 2)
    assert(config.addressability > 0)

    let builder = SMNetBuilder()

    genBRAMTimer(config: config, into: builder, global: true)

    return builder.module
}
