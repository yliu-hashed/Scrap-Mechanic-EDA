//
//  SM Check.swift
//  Scrap Mechanic EDA
//

extension SMModule {
    public func check() throws(NetlistError) {
        // check connections
        for (gateId, gate) in gates {
            for dstId in gate.dsts {
                // check that all nodes of all destinations exist
                guard let dstNode = gates[dstId] else {
                    throw NetlistError.danglingGate(gateId: dstId)
                }
                // check destinations dst have source
                guard dstNode.srcs.contains(gateId) else {
                    throw NetlistError.asymDst(gateId: gateId, dstId: dstId)
                }
            }

            for srcId in gate.srcs {
                // check that all nodes of all sources exist
                guard let srcNode = gates[srcId] else {
                    throw NetlistError.danglingGate(gateId: srcId)
                }
                // check sources dst have destination
                guard srcNode.dsts.contains(gateId) else {
                    throw NetlistError.asymSrc(gateId: gateId, srcId: srcId)
                }

                // check that all sources does not source back
                guard !srcNode.srcs.contains(gateId) else {
                    throw NetlistError.twoCycle(gateId1: gateId, gateId2: srcId)
                }
                // check that all sources does not connect to itself
                guard srcId != gateId else {
                    throw NetlistError.selfConnection(gateId: gateId)
                }
            }

            // check that only sequential gate can have portal
            let hasPortal = !gate.portalDsts.isEmpty || !gate.portalSrcs.isEmpty
            if hasPortal && !gate.isSequential {
                throw NetlistError.combPortal(gateId: gateId)
            }

            for dstId in gate.portalDsts.keys {
                // check that all nodes of all destinations exist
                guard let dstNode = gates[dstId] else {
                    throw NetlistError.danglingGate(gateId: dstId)
                }
                // check destinations dst have source
                guard dstNode.portalSrcs.keys.contains(gateId) else {
                    throw NetlistError.asymPortalDst(gateId: gateId, dstId: dstId)
                }
            }

            for srcId in gate.portalSrcs.keys {
                // check that all nodes of all sources exist
                guard let srcNode = gates[srcId] else {
                    throw NetlistError.danglingGate(gateId: srcId)
                }
                // check sources dst have destination
                guard srcNode.portalDsts.keys.contains(gateId) else {
                    throw NetlistError.asymPortalSrc(gateId: gateId, srcId: srcId)
                }
            }

            // check output limit
            if gate.dsts.count > SMModule.gateOutputLimit {
                throw NetlistError.tooManyOutput(gateId: gateId, count: gate.dsts.count)
            }
            // check timer has one input
            if case .timer(_) = gate.type, gate.srcs.count > 1 {
                throw NetlistError.timerManyInput(gateId: gateId)
            }
        }

        // check inputs
        for (name, port) in inputs {
            for (index, gateId) in port.gates.enumerated() {
                // check input exists
                guard let gate = gates[gateId] else {
                    throw NetlistError.missingPortGate(port: name, index: index, gateId: gateId)
                }
                switch gate.type {
                case .timer(_):
                    throw NetlistError.portIsTimer(port: name, index: index, gateId: gateId)
                case .logic(let logicType):
                    // inputs must be non-inverting
                    if logicType.isInverter {
                        throw NetlistError.inputIsInverter(port: name, index: index, gateId: gateId)
                    }
                }
            }
        }

        // check outputs
        for (name, port) in outputs {
            for (index, gateId) in port.gates.enumerated() {
                // check output exists
                guard let gate = gates[gateId] else {
                    throw NetlistError.missingPortGate(port: name, index: index, gateId: gateId)
                }
                switch gate.type {
                case .timer(_):
                    throw NetlistError.portIsTimer(port: name, index: index, gateId: gateId)
                case .logic(_):
                    break
                }
            }
        }
    }
}
