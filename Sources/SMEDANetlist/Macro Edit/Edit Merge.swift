//
//  Edit Merge.swift
//  Scrap Mechanic EDA
//

func editMerge(
    _ mainModule: inout SMModule,
    with modules: [SMModule]
) throws {

    // get unique ids
    var counter: UInt64 = 0
    func getNextFreeId() -> UInt64 {
        while mainModule.gates.keys.contains(counter) {
            counter += 1
        }
        defer { counter += 1 }
        return counter
    }

    // merge gates into main
    var mergeLookup: [String: [UInt64: UInt64]] = [:]
    for module in modules {
        let name = module.name
        // a lookup keyed by old id to new id
        var lookup: [UInt64: UInt64] = [:]
        lookup.reserveCapacity(module.gates.count)

        // merge gates
        for (gateId, gate) in module.gates {
            let newGateId = getNextFreeId()
            mainModule.gates.updateValue(gate, forKey: newGateId)
            lookup.updateValue(newGateId, forKey: gateId)
            if module.sequentialNodes.contains(gateId) {
                mainModule.sequentialNodes.insert(newGateId)
            }
        }

        // update connection
        for gateId in module.gates.keys {
            let srcs = mainModule.gates[lookup[gateId]!]!.srcs
            let dsts = mainModule.gates[lookup[gateId]!]!.dsts
            let newSrcs = srcs.map { lookup[$0]! }
            let newDsts = dsts.map { lookup[$0]! }
            mainModule.gates[lookup[gateId]!]!.srcs = Set(newSrcs)
            mainModule.gates[lookup[gateId]!]!.dsts = Set(newDsts)
        }

        // update portals
        for gateId in module.gates.keys {
            let srcs = mainModule.gates[lookup[gateId]!]!.portalSrcs
            let dsts = mainModule.gates[lookup[gateId]!]!.portalDsts
            let newSrcs = srcs.map { (lookup[$0.key]!, $0.value) }
            let newDsts = dsts.map { (lookup[$0.key]!, $0.value) }
            mainModule.gates[lookup[gateId]!]!.portalSrcs = Dictionary(uniqueKeysWithValues: newSrcs)
            mainModule.gates[lookup[gateId]!]!.portalDsts = Dictionary(uniqueKeysWithValues: newDsts)
        }

        // register lookup
        mergeLookup.updateValue(lookup, forKey: name)
    }

    // lower inputs and outputs
    for module in modules {
        let name = module.name
        for (portName, port) in module.outputs {
            let newPortName = name + "." + portName
            let transferedList = port.gates.map { mergeLookup[name]![$0]! }
            let newPort = SMModule.Port(
                gates: transferedList,
                isClock: port.isClock,
                colorHex: port.colorHex,
                device: port.device
            )
            mainModule.outputs.updateValue(newPort, forKey: newPortName)
        }
        for (portName, port) in module.inputs {
            let newPortName = name + "." + portName
            let transferedList = port.gates.map { mergeLookup[name]![$0]! }
            let newPort = SMModule.Port(
                gates: transferedList,
                isClock: port.isClock,
                colorHex: port.colorHex,
                device: port.device
            )
            mainModule.inputs.updateValue(newPort, forKey: newPortName)
        }
    }
}
