//
//  BRAM Timer Read.swift
//  Scrap Mechanic EDA
//

import Foundation

func genReadPort(
    config: borrowing BRAMTimerConfig, builder: SMNetBuilder,
    portInfo: borrowing BRAMTimerPortInfo, clock: borrowing [UInt64],
    loopBank: borrowing [TimerLoopInfo]
) {

    // generate clock match signal
    let match = builder.addLogic(type: .and)
    var matchers: [UInt64] = []
    matchers.reserveCapacity(config.clockAddressSpacePow2)
    for i in 0..<config.clockAddressSpacePow2 {
        let matcher = builder.addLogic(type: .xnor)
        builder.connect([clock[i], portInfo.address[i]], to: matcher)
        builder.connect(matcher, to: match)
        matchers.append(matcher)
    }

    // generate address inverters
    var upperAddrT: [UInt64] = []
    var upperAddrN: [UInt64] = []
    upperAddrT.reserveCapacity(config.multiplexityPow2)
    upperAddrN.reserveCapacity(config.multiplexityPow2)

    for i in 0..<config.multiplexityPow2 {
        let addrIndex = i + config.clockAddressSpacePow2
        let addr = portInfo.address[addrIndex]
        let t = builder.addLogic(type: .and)
        let n = builder.addLogic(type: .nand)
        builder.connect(addr, to: [t, n])
        upperAddrT.append(t)
        upperAddrN.append(n)
    }

    // generate match signal for each bank
    var matchBanks: [UInt64] = []
    matchBanks.reserveCapacity(config.multiplexity)
    for i in 0..<config.multiplexity {
        let bankMatch = builder.addLogic(type: .and)
        // connect clock match
        builder.connect(match, to: bankMatch)
        // connect upper address match
        for b in 0..<config.multiplexityPow2 {
            let value = (i & (1 << b)) != 0
            let gate = value ? upperAddrT[b] : upperAddrN[b]
            builder.connect(gate, to: bankMatch)
        }
        let delayMatch = builder.addTimer(delay: 2)
        builder.connect(bankMatch, to: delayMatch)
        matchBanks.append(delayMatch)
    }

    // generate read gating for each bank
    var readSums: [UInt64] = []
    readSums.reserveCapacity(config.addressability)
    for b in 0..<config.addressability {
        let summer = builder.addLogic(type: .or)
        for i in 0..<config.multiplexity {
            let gate = builder.addLogic(type: .and)
            builder.connect(loopBank[i].dataO[b], to: gate)
            builder.connect(matchBanks[i], to: gate)
            builder.connect(gate, to: summer)
        }
        readSums.append(summer)
    }

    let delayMatch = builder.addTimer(delay: 6)
    builder.connect(match, to: delayMatch)

    // build output register
    for i in 0..<config.addressability {
        let dff = genDFF(builder: builder, clkPulse: [delayMatch], data: readSums[i])
        builder.connect(dff, to: portInfo.readData[i])
        for matcher in matchers {
            builder.portal(matcher, to: dff, delay: config.timerCycleLength + 11)
        }
    }
}
