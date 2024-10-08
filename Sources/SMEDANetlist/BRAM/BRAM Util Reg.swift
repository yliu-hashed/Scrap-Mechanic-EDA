//
//  BRAM Util Reg.swift
//  Scrap Mechanic EDA
//

func genDFF(builder: SMNetBuilder, clkPulse: [UInt64], data: UInt64, keepTiming: Bool? = nil) -> UInt64 {

    let xlp0 = builder.addLogic(type: .xor, keepTiming: true)
    let xlp1 = builder.addLogic(type: .xor, keepTiming: true)
    let xlp2 = builder.addLogic(type: .xor, keepTiming: true)
    let diff = builder.addLogic(type: .xor, keepTiming: keepTiming)
    let filt = builder.addLogic(type: .and, keepTiming: true)

    // connect inputs
    builder.connect(data, to: diff)
    builder.connect(clkPulse, to: filt)
    // connect primary store loop
    builder.connect(chain: xlp0, xlp1, xlp2, xlp0)
    // connect change detection
    builder.connect(chain: xlp0, diff, filt)
    // connect change circuit
    builder.connect(filt, to: [xlp0, xlp1, xlp2])

    return xlp1
}
