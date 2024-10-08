//
//  BRAM Timer Clock.swift
//  Scrap Mechanic EDA
//

/*----------- CLOCK BIT -----------*/
/*              .--<--.            */
/*              |     |            */
/*            xor1    |            */
/* ...   ... /  |     |            */
/*   \   /  / xor2    |            */
/*    \ /  / /  |     |            */
/*     clkctl-xor3----|--[clkout]  */
/*      \     / |     |            */
/*       \   /  '-->--'            */
/*        \ /                      */
/*     [clkctl+1]                  */
/*---------------------------------*/

public class BRAMTimerCache {
    var builder: SMNetBuilder

    var delays: [UInt64] = []
    var usage: Int = 0
    var lastValue: UInt64! = nil
    var lastControl: UInt64? = nil

    public init(builder: SMNetBuilder) {
        self.builder = builder
    }

    func getClockTree(length: Int) -> [UInt64] {
        precondition(length >= 1)

        if delays.isEmpty || usage >= 256 {
            let zero = builder.addLogic(type: .or)
            lastValue = builder.addLogic(type: .nor)
            lastControl = nil
            builder.connect(zero, to: lastValue)
            delays = []
            usage = 0
        }

        while delays.count < length {
            // create xor loop
            let xor1 = builder.addLogic(type: .xor)
            let xor2 = builder.addLogic(type: .xor)
            let xor3 = builder.addLogic(type: .xor)
            builder.connect(chain: xor1, xor2, xor3, xor1)
            // create control bit
            let clkctl = builder.addLogic(type: .and)
            builder.connect(clkctl, to: [xor1, xor2, xor3])
            builder.connect(lastValue, to: clkctl)
            if let lastControl = lastControl {
                builder.connect(lastControl, to: clkctl)
            }
            lastValue = xor1
            lastControl = clkctl
            // create sync timer
            // since carry line has delay, these timers ensure clock signal arrive at the same time
            for timerId in delays {
                let oldDelay: Int
                if case .timer(let delay) = builder.module.gates[timerId]!.type {
                    oldDelay = delay
                } else {
                    oldDelay = 0
                }
                builder.changeGateType(of: timerId, to: .timer(delay: oldDelay + 1))
            }
            let delayTimer = builder.addLogic(type: .or)
            builder.connect(xor1, to: delayTimer)
            delays.append(delayTimer)
        }

        usage += 1

        return delays
    }
}

/// Generate a tick-incrementing clock
func genClock(config: borrowing BRAMTimerConfig, builder: SMNetBuilder, cache: BRAMTimerCache? = nil) -> [UInt64] {
    let cache = cache ?? BRAMTimerCache(builder: builder)
    return cache.getClockTree(length: config.clockAddressSpacePow2)
}
