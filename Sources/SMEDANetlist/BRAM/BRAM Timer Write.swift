//
//  BRAM Timer Write.swift
//  Scrap Mechanic EDA
//

func genBRAMTimerWritePort(
    config: borrowing BRAMTimerConfig, builder: SMNetBuilder,
    portInfo: borrowing BRAMTimerPortInfo, clock: borrowing [UInt64],
    loopBank: borrowing [TimerLoopInfo], clkPulse: UInt64
) {

    // data buffer
    var dataBuffer: [UInt64] = []
    dataBuffer.reserveCapacity(config.addressability)
    for i in 0..<config.addressability {
        let buffer = genDFF(builder: builder, clkPulse: [clkPulse], data: portInfo.writeData[i], keepTiming: false)
        let delayedBuffer = builder.addTimer(delay: 3)
        builder.connect(buffer, to: delayedBuffer)
        dataBuffer.append(delayedBuffer)
    }

    // address buffer
    var addrBuffer: [UInt64] = []
    addrBuffer.reserveCapacity(config.addressSpacePow2)
    for i in 0..<config.addressSpacePow2 {
        let buffer = genDFF(builder: builder, clkPulse: [clkPulse], data: portInfo.address[i], keepTiming: false)
        addrBuffer.append(buffer)
    }

    // write enable buffer
    let weBuffer = genDFF(builder: builder, clkPulse: [clkPulse], data: portInfo.writeEnable, keepTiming: false)

    // generate clock match signal
    let match = builder.addLogic(type: .and)
    builder.connect(weBuffer, to: match)
    for i in 0..<config.clockAddressSpacePow2 {
        let matcher = builder.addLogic(type: .xnor)
        builder.connect([clock[i], addrBuffer[i]], to: matcher)
        builder.connect(matcher, to: match)
    }

    // generate match signal for each bank
    for i in 0..<config.multiplexity {
        let bankMatch = loopBank[i].write
        // connect clock match
        builder.connect(match, to: bankMatch)
        // connect upper address match
        let posMatch = builder.addLogic(type: .and)
        let negMatch = builder.addLogic(type: .nor)
        for b in 0..<config.multiplexityPow2 {
            let value = (i & (1 << b)) != 0
            let target = value ? posMatch : negMatch
            builder.connect(addrBuffer[b + config.clockAddressSpacePow2], to: target)
        }
        builder.connect([posMatch, negMatch], to: bankMatch)
        if builder.module.gates[posMatch]!.srcs.isEmpty { builder.removeGate(posMatch) }
        if builder.module.gates[negMatch]!.srcs.isEmpty { builder.removeGate(negMatch) }
    }

    // connect write data to banks
    for i in 0..<config.multiplexity {
        let bankDataI = loopBank[i].dataI
        for b in 0..<config.addressability {
            builder.connect(dataBuffer[b], to: bankDataI[b])
        }
    }
}
