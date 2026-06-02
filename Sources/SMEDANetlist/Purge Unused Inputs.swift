//
//  Purge Unused Inputs.swift
//  Scrap Mechanic EDA
//

/// Remove unused inputs.
public func removeUnusedInputs(
    builder: SMNetBuilder
) {
    let inputs = builder.module.inputs
    for (portName, port) in inputs {
        guard port.gates.allSatisfy({ builder.module.gates[$0]!.dsts.isEmpty }) else { continue }
        builder.unregisterInputGates(port: portName)
        for gateId in port.gates {
            builder.removeGate(gateId)
        }
    }
}
