//
//  SM Net Builder.swift
//  Scrap Mechanic EDA
//

public class SMNetBuilder {
    private var nodeIdCounter: UInt64 = 0
    public private(set) var module: SMModule
    public private(set) var inputIds: Set<UInt64> = []
    public private(set) var outputIds: Set<UInt64> = []

    public var defaultDomain: SMGate.Domain = .combinational

    public init(module: SMModule = SMModule()) {
        nodeIdCounter = module.nextId()
        for port in module.inputs.values {
            inputIds.formUnion(port.gates)
        }
        for port in module.outputs.values {
            outputIds.formUnion(port.gates)
        }
        self.module = module
    }

    public func setName(name: String) {
        module.name = name
    }

    public func registerInputGates(port: String, gates: [UInt64], isClock: Bool = false) {
        module.inputs[port] = SMModule.Port(gates: gates)
        inputIds.formUnion(gates)
    }

    public func unregisterInputGates(port: String) {
        guard let port = module.inputs.removeValue(forKey: port) else { return }
        inputIds.subtract(port.gates)
    }

    public func registerOutputGates(port: String, gates: [UInt64], isClock: Bool = false) {
        module.outputs[port] = SMModule.Port(gates: gates)
        outputIds.formUnion(gates)
    }

    public func unregisterOutputGates(port: String) {
        guard let port = module.outputs.removeValue(forKey: port) else { return }
        outputIds.subtract(port.gates)
    }

    @discardableResult public func addLogic(type: SMLogicType, into domain: SMGate.Domain? = nil) -> UInt64 {
        return addGate(type: .logic(type: type), into: domain)
    }

    @discardableResult public func addTimer(delay: Int, into domain: SMGate.Domain? = nil) -> UInt64 {
        return addGate(type: .timer(delay: delay), into: domain)
    }

    @discardableResult public func addGate(type: SMGateType, into domain: SMGate.Domain? = nil) -> UInt64 {
        let thisId = nodeIdCounter
        let domain = domain ?? defaultDomain
        module.gates.updateValue(SMGate(type: type, domain: domain), forKey: thisId)
        nodeIdCounter += 1
        return thisId
    }

    public func changeGateType(of id: UInt64, to newType: SMGateType) {
        assert(module.gates.keys.contains(id))
        module.gates[id]?.type = newType
    }

    public func removeGate(_ id: UInt64) {
        let gate = module.gates.removeValue(forKey: id)
        guard let gate = gate else { return }
        assert(!inputIds.contains(id), "Cannot delete an registered input")
        assert(!outputIds.contains(id), "Cannot delete an registered output")

        for nodeId in gate.srcs { module.gates[nodeId]!.dsts.remove(id) }
        for nodeId in gate.dsts { module.gates[nodeId]!.srcs.remove(id) }
        for nodeId in gate.portalSrcs.keys { module.gates[nodeId]!.portalDsts.removeValue(forKey: id) }
        for nodeId in gate.portalDsts.keys { module.gates[nodeId]!.portalSrcs.removeValue(forKey: id) }
    }

    public func portal(_ src: UInt64, to dst: UInt64, delay: Int, keepOldDelay: Bool = false) {
        assert(module.gates.keys.contains(src), "Gate \(src) does not exist")
        assert(module.gates.keys.contains(dst), "Gate \(dst) does not exist")
        assert(src != dst, "Gate \(dst) cannot connect to itself")
        let newDelay: Int
        if keepOldDelay {
            let oldDelay = module.gates[src]!.portalDsts[dst] ?? 0
            newDelay = max(oldDelay, delay)
        } else {
            newDelay = delay
        }
        module.gates[src]!.portalDsts[dst] = newDelay
        module.gates[dst]!.portalSrcs[src] = newDelay
    }

    public func transferPortals(from src: UInt64, to dst: UInt64, delayDelta: Int = 0) {
        assert(module.gates.keys.contains(src), "Gate \(src) does not exist")
        assert(module.gates.keys.contains(dst), "Gate \(dst) does not exist")
        assert(src != dst, "Gate \(dst) cannot connect to itself")
        for (portalDstId, delay) in module.gates[src]!.portalDsts {
            portal(dst, to: portalDstId, delay: max(delay - delayDelta, 0))
        }
        for (portalSrcId, delay) in module.gates[src]!.portalSrcs {
            portal(dst, to: portalSrcId, delay: max(delay + delayDelta, 0))
        }
    }

    public func connect(chain first: UInt64, _ second: UInt64, _ ids: UInt64...) {
        var tmp: UInt64 = first
        func conn(to next: UInt64) {
            connect(tmp, to: next)
            tmp = next
        }
        conn(to: second)
        for id in ids { conn(to: id) }
    }

    public func connect(_ src: UInt64, to dst: UInt64) {
        assert(module.gates.keys.contains(src), "Gate \(src) does not exist")
        assert(module.gates.keys.contains(dst), "Gate \(dst) does not exist")
        assert(src != dst, "Gate \(dst) cannot connect to itself")
        module.gates[dst]!.srcs.update(with: src)
        module.gates[src]!.dsts.update(with: dst)
    }

    public func connect(_ src: some Collection<UInt64>, to dst: UInt64) {
        src.forEach { assert(module.gates.keys.contains($0), "Gate \($0) does not exist") }
        assert(module.gates.keys.contains(dst), "Gate \(dst) does not exist")
        assert(!src.contains(dst), "Gate \(dst) cannot connect to itself")
        module.gates[dst]!.srcs.formUnion(src)
        for s in src {
            module.gates[s]!.dsts.update(with: dst)
        }
    }

    public func connect(_ src: UInt64, to dst: some Collection<UInt64>) {
        assert(module.gates.keys.contains(src), "Gate \(src) does not exist")
        dst.forEach { assert(module.gates.keys.contains($0), "Gate \($0) does not exist") }
        assert(!dst.contains(src), "Gate \(src) cannot connect to itself")
        for d in dst {
            module.gates[d]!.srcs.update(with: src)
        }
        module.gates[src]!.dsts.formUnion(dst)
    }

    public func disconnect(_ src: UInt64, to dst: UInt64) {
        assert(module.gates.keys.contains(src), "Gate \(src) does not exist")
        assert(module.gates.keys.contains(dst), "Gate \(dst) does not exist")
        module.gates[dst]!.srcs.remove(src)
        module.gates[src]!.dsts.remove(dst)
    }

    public func disconnect(_ src: some Collection<UInt64>, to dst: UInt64) {
        src.forEach { assert(module.gates.keys.contains($0), "Gate \($0) does not exist") }
        assert(module.gates.keys.contains(dst), "Gate \(dst) does not exist")
        module.gates[dst]!.srcs.subtract(src)
        for s in src {
            module.gates[s]!.dsts.remove(dst)
        }
    }

    public func disconnect(_ src: UInt64, to dst: some Collection<UInt64>) {
        assert(module.gates.keys.contains(src), "Gate \(src) does not exist")
        dst.forEach { assert(module.gates.keys.contains($0), "Gate \($0) does not exist") }
        for d in dst {
            module.gates[d]!.srcs.remove(src)
        }
        module.gates[src]!.dsts.subtract(dst)
    }

    /// Ensure that the logic network is a legal SM network, by adding gates that reduce the input
    /// count of some gates under 256.
    @discardableResult public func legalize() -> Bool {
        var changed: Bool = false
        // reduce the connection count below the alloed limit
        let allGateIds = Set(module.gates.keys)
        for gateId in allGateIds {
            let gate = module.gates[gateId]!
            guard gate.dsts.count > SMModule.gateOutputLimit else { continue }
            changed = true
            // disconnect the overused node from it's destinations
            let dsts: Set<UInt64>
            if gate.isSequential {
                dsts = gate.dsts.filter { !module.gates[$0]!.isSequential }
            } else {
                dsts = gate.dsts
            }

            disconnect(gateId, to: dsts)

            // the number of intermediate nodes required to make it work
            let tmpCount = (dsts.count + SMModule.gateOutputLimit - 1) / SMModule.gateOutputLimit

            // create the temporary nodes, and connect from the sources to them
            var tmps = [UInt64](repeating: 0, count: tmpCount)
            for i in 0..<tmpCount {
                tmps[i] = addLogic(type: .or, into: gate.domain)
            }
            connect(gateId, to: tmps)

            // connects the tmps to destinations
            for (i, dst) in dsts.enumerated() {
                let targetTmpIndex = i / SMModule.gateOutputLimit
                connect(tmps[targetTmpIndex], to: dst)
            }
        }
        return changed
    }
}
