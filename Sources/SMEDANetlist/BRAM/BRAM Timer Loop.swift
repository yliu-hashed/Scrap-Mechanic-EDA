//
//  BRAM Timer Loop.swift
//  Scrap Mechanic EDA
//

/*------------- GATES --------X----------- NAMES ----------*/
/*    .-->pass<---[write]'    |   .--->and<---[write]'     */
/*    |     |     [write]     |   |     |     [write]      */
/*  timer   |      |          | timer   |      |           */
/*    ↑     ↓      ↓          |   ↑     ↓      ↓           */
/*    '---join<---filt<--[in] |   '----or<----and<---[in]  */
/*          |                 |         |                  */
/*        [data]              |       [data]               */
/*----------------------------X----------------------------*/

struct TimerLoopInfo {
    var write: UInt64
    var dataI: [UInt64]
    var dataO: [UInt64]
}

/// Generate a timer loop to store memory
func genBRAMTimerLoop(builder: SMNetBuilder, count: Int, length: Int) -> TimerLoopInfo {
    assert(length >= 4)

    var dataI = [UInt64](repeating: 0, count: count)
    var dataO = [UInt64](repeating: 0, count: count)

    let write = builder.addLogic(type: .and)
    let wt = builder.addLogic(type: .and)
    let wn = builder.addLogic(type: .nand)
    builder.connect(write, to: [wt, wn])

    for i in 0..<count {
        let timer  = builder.addTimer(delay: length - 3)
        let passer = builder.addLogic(type: .and)
        let joiner = builder.addLogic(type: .or)
        let filter = builder.addLogic(type: .and)
        builder.connect(chain: timer, passer, joiner, timer)
        builder.connect(wn, to: passer)
        builder.connect(filter, to: joiner)
        builder.connect(wt, to: filter)

        dataI[i] = filter
        dataO[i] = joiner
    }

    return TimerLoopInfo(write: write, dataI: dataI, dataO: dataO)
}

func genBRAMTimerLoopBank(config: borrowing BRAMTimerConfig, builder: SMNetBuilder) -> [TimerLoopInfo] {
    let sectorCount = config.multiplexity

    var loopOutputs: [TimerLoopInfo] = []
    loopOutputs.reserveCapacity(sectorCount)

    for _ in 0..<sectorCount {
        let loopData = genBRAMTimerLoop(
            builder: builder,
            count: config.addressability,
            length: config.timerCycleLength
        )
        loopOutputs.append(loopData)
    }

    return loopOutputs
}
