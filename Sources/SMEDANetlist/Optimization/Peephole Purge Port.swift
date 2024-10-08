//
//  Peephole Purge Port.swift
//  Scrap Mechanic EDA
//

@discardableResult
public func peepoptPurgePort(builder: SMNetBuilder) -> Bool {
    var everChanged = false

    while true {
        let changed = purgePortPass(builder: builder)
        if changed { everChanged = true }
        if !changed { break }
    }

    return everChanged
}

private func purgePortPass(builder: SMNetBuilder) -> Bool {
    var changed = false

    let inputs = builder.module.inputs
    for (portName, port) in inputs {
        let allEmpty = port.gates.allSatisfy({ builder.module.gates[$0]!.dsts.isEmpty })
        if allEmpty {
            builder.unregisterInputGates(port: portName)
            for gateId in port.gates {
                builder.removeGate(gateId)
            }
            changed = true
        }
    }

    return changed
}
