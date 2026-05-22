//
//  BRAM Util Reg.swift
//  Scrap Mechanic EDA
//

func genDFF(builder: SMNetBuilder, clkPulse: [UInt64], data: UInt64, domain: SMGate.Domain? = nil) -> UInt64 {

    let xlp0 = builder.addLogic(type: .xor, into: .sequential)
    let xlp1 = builder.addLogic(type: .xor, into: .sequential)
    let xlp2 = builder.addLogic(type: .xor, into: .sequential)
    let diff = builder.addLogic(type: .xor, into: domain)
    let filt = builder.addLogic(type: .and, into: .sequential)

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
