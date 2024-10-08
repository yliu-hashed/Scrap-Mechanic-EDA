//
//  BRAM DFF.swift
//  Scrap Mechanic EDA
//

public struct BRAMDFFConfig {
    public var addressability: Int
    public var addressSpacePow2: Int
    public var ports: [BRAMPortConfig]

    public init(addressability: Int = 8, addressSpacePow2: Int, ports: [BRAMPortConfig] = [.readWrite]) {
        self.addressability = addressability
        self.addressSpacePow2 = addressSpacePow2
        self.ports = ports
    }
}

private struct DFF {
    var xors: [UInt64]
}

private func generateDFF(builder: SMNetBuilder, clkPulse: UInt64) -> DFF {
    let xlp0 = builder.addLogic(type: .xor, keepTiming: true)
    let xlp1 = builder.addLogic(type: .xor, keepTiming: true)
    let xlp2 = builder.addLogic(type: .xor, keepTiming: true)
    builder.connect(chain: xlp0, xlp1, xlp2, xlp0)

    return DFF(xors: [xlp0, xlp1, xlp2])
}

public func genBRAMDFF(config: borrowing BRAMDFFConfig) -> SMModule {
    let dffCount = (1 << config.addressSpacePow2) * config.addressability

    let writePortCount = config.ports.lazy.filter({ $0.hasWrite }).count

    let builder = SMNetBuilder()
    // MARK: Clock Port
    let clk = builder.addLogic(type: .and, keepTiming: true)
    builder.registerInputGates(port: "CLK", gates: [clk])
    let clkInv = builder.addLogic(type: .nor, keepTiming: true)
    builder.connect(clk, to: clkInv)
    let clkPulse = builder.addLogic(type: .and, keepTiming: true)
    builder.connect([clk, clkInv], to: clkPulse)
    let clkPulseTree = builder.buildDriveTree(srcId: clkPulse, fanout: dffCount * writePortCount, keepTiming: true)

    // MARK: Generate DFF
    var memoryElements: [[DFF]] = []
    memoryElements.reserveCapacity(1 << config.addressSpacePow2)
    for _ in 0..<(1 << config.addressSpacePow2) {
        var word: [DFF] = []
        word.reserveCapacity(config.addressability)
        for _ in 0..<config.addressability {
            word.append(generateDFF(builder: builder, clkPulse: clkPulse))
        }
        memoryElements.append(word)
    }

    for (portIndex, port) in config.ports.enumerated() {
        // MARK: Address Port
        var addressLine: [UInt64] = []
        var addressLineBuf: [UInt64] = []
        var addressLineInv: [UInt64] = []
        var decoder: [UInt64] = []
        for _ in 0..<config.addressSpacePow2 {
            let addr = builder.addLogic(type: .and)
            let addrBuf = builder.addLogic(type: .and)
            let addrInv = builder.addLogic(type: .nor)
            builder.connect(addr, to: [addrInv, addrBuf])
            addressLine.append(addr)
            addressLineBuf.append(addrBuf)
            addressLineInv.append(addrInv)
        }
        builder.registerInputGates(port: "\(portIndex)ADDR", gates: addressLine)
        // address mux
        for addr in 0..<(1 << config.addressSpacePow2) {
            let select = builder.addLogic(type: .and)
            for i in 0..<config.addressSpacePow2 {
                let isOn = (addr & (1 << i)) != 0
                let bit = isOn ? addressLineInv[i] : addressLineBuf[i]
                builder.connect(bit, to: select)
            }
            decoder.append(select)
        }

        // MARK: Read Port
        if port.hasRead {
            var readPort: [UInt64] = []
            for _ in 0..<config.addressability {
                let bit = builder.addLogic(type: .or)
                readPort.append(bit)
            }
            builder.registerOutputGates(port: "\(portIndex)DATAO", gates: readPort)
            for addr in 0..<(1 << config.addressSpacePow2) {
                let select = decoder[addr]
                let dffs = memoryElements[addr]
                for (i, dff) in dffs.enumerated() {
                    let mask = builder.addLogic(type: .and)
                    builder.connect([dff.xors[2], select], to: mask)
                    builder.connect(mask, to: readPort[i])
                }
            }
        }

        // MARK: Write Port
        if port.hasWrite {
            var writeData: [UInt64] = []
            for _ in 0..<config.addressability {
                let bit = builder.addLogic(type: .and)
                writeData.append(bit)
            }
            let writeEnable = builder.addLogic(type: .and)
            let writeEnableTree = builder.buildDriveTree(srcId: writeEnable, fanout: dffCount)
            builder.registerInputGates(port: "\(portIndex)DATAI", gates: writeData)
            builder.registerInputGates(port: "\(portIndex)WE", gates: [writeEnable])
            for addr in 0..<(1 << config.addressSpacePow2) {
                let select = decoder[addr]
                let dffs = memoryElements[addr]
                for (i, dff) in dffs.enumerated() {
                    let diff = builder.addLogic(type: .xor)
                    let filt = builder.addLogic(type: .and, keepTiming: true)
                    builder.connect(chain: dff.xors[0], diff, filt)
                    builder.connect(filt, to: dff.xors)
                    builder.connect(clkPulseTree.use(), to: filt)
                    builder.connect(writeEnableTree.use(), to: filt)
                    builder.connect(select, to: filt)
                    builder.connect(writeData[i], to: diff)
                }
            }
        }
    }

    return builder.module
}
