//
//  Sim Input.swift
//  Scrap Mechanic EDA
//

import SMEDANetlist

extension SimulationModel {

    func setInput(constant: UInt64, port: Port) -> Bool {
        guard let gates = module.inputs[port.port]?.gates else {
            print(for: .error, "Port '\(port.port)' cannot be found.")
            return false
        }

        let msb: Int
        let lsb: Int
        var width: Int { msb - lsb + 1 }

        if port.isAll {
            lsb = 0
            msb = gates.count - 1
        } else {
            guard gates.indices.contains(port.lsb...port.msb) else {
                print(for: .error, "Port '\(port.port)' does not contain all of index of \(port.lsb)...\(port.msb).")
                return false
            }
            msb = port.msb
            lsb = port.lsb
        }

        for i in 0..<width {
            let index = lsb + i
            let gateId = gates[index]
            let state = (constant & 1 << i) != 0
            override(gateId, to: state)
        }

        return true
    }

    func getOutput(port: Port) -> UInt64? {
        guard let gates = module.outputs[port.port]?.gates else {
            print(for: .error, "Port '\(port.port)' cannot be found.")
            return nil
        }

        let msb: Int
        let lsb: Int
        var width: Int { msb - lsb + 1 }

        if port.isAll {
            lsb = 0
            msb = gates.count - 1
        } else {
            guard gates.indices.contains(port.lsb...port.msb) else {
                print(for: .error, "Port '\(port.port)' does not contain all of index of \(port.lsb)...\(port.msb).")
                return nil
            }
            msb = port.msb
            lsb = port.lsb
        }

        var value: UInt64 = 0

        for i in 0..<width {
            let index = lsb + i
            let gateId = gates[index]
            let state = output(of: gateId)

            value |= state ? (1 << i) : 0
        }

        return value
    }
}
