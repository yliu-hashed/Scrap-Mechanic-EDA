//
//  Simulation Extensions.swift
//  Scrap Mechanic EDA
//

import SMEDANetlist

extension SimulationModel {

    func setInput(_ port: String, to constant: UInt64) -> Bool {
        precondition(module.inputs.keys.contains(port), "No input named '\(port)'.")
        let gates = module.inputs[port]!.gates

        for (index, gateId) in gates.enumerated() {
            let state = (constant & (1 << index)) != 0
            override(gateId, to: state)
        }

        return true
    }

    func getOutput(of port: String) -> UInt64 {
        precondition(module.outputs.keys.contains(port), "No output named '\(port)'.")
        let gates = module.outputs[port]!.gates

        var value: UInt64 = 0

        for (index, gateId) in gates.enumerated() {
            let state = output(of: gateId)
            value |= state ? (1 << index) : 0
        }

        return value
    }

}
