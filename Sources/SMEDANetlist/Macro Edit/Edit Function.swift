//
//  Edit Function.swift
//  Scrap Mechanic EDA
//

public struct EditPort: CustomStringConvertible {
    public let port: String
    public let msb: Int
    public let lsb: Int

    public var width: Int { msb - lsb + 1 }

    public init(port: String, msb: Int, lsb: Int) {
        self.port = port
        self.msb = msb
        self.lsb = lsb
    }

    public var description: String {
        return "\(port)[\(msb):\(lsb)]"
    }
}

public struct EditPortRoute: CustomStringConvertible {
    public let srcPort: EditPort
    public let dstPort: EditPort

    public init(srcPort: EditPort, dstPort: EditPort) {
        self.srcPort = srcPort
        self.dstPort = dstPort
    }

    public var description: String { srcPort.description + "->" + dstPort.description }
}

public struct EditPortDrive: CustomStringConvertible {
    public let constant: UInt64
    public let dstPort: EditPort

    public init(constant: UInt64, dstPort: EditPort) {
        self.constant = constant
        self.dstPort = dstPort
    }

    public var description: String { "\(constant)->" + dstPort.description }
}

public struct EditFunction {
    public let mergeNetlists: [SMModule]
    public let portConnect: [EditPortRoute]
    public let portShare: [EditPortRoute]
    public let portDrive: [EditPortDrive]
    public let portRemove: [EditPort]
    public let force: Bool

    public init(
        merge: [SMModule] = [],
        connect: [EditPortRoute] = [],
        share: [EditPortRoute] = [],
        drive: [EditPortDrive] = [],
        remove: [EditPort] = [],
        force: Bool = false
    ) {
        mergeNetlists = merge
        portConnect = connect
        portShare = share
        portDrive = drive
        portRemove = remove
        self.force = force
    }

    public func run(_ module: inout SMModule) throws {
        if !mergeNetlists.isEmpty {
            try editMerge(&module, with: mergeNetlists)
        }
        var invalidInputGates: Set<UInt64> = []
        var invalidOutputGates: Set<UInt64> = []
        if !portConnect.isEmpty {
            try editPortConnect(&module, portRouteTable: portConnect, invalidInputGates: &invalidInputGates)
        }
        if !portShare.isEmpty {
            try editPortShare(&module, portRouteTable: portConnect, invalidInputGates: &invalidInputGates)
        }
        if !portDrive.isEmpty {
            try editPortDrive(&module, drives: portDrive, invalidInputGates: &invalidInputGates)
        }
        if !portRemove.isEmpty {
            try editPortIgnore(&module, ports: portRemove, invalidOutputGates: &invalidOutputGates)
        }
        // rectify ports
        var eliminatedInputPorts: Set<String> = []
        for portName in module.inputs.keys {
            module.inputs[portName]!.gates
                .removeAll(where: { invalidInputGates.contains($0) })
            if module.inputs[portName]!.gates.isEmpty {
                eliminatedInputPorts.insert(portName)
            }
        }
        for portName in eliminatedInputPorts {
            module.inputs.removeValue(forKey: portName)
        }

        var eliminatedOutputPorts: Set<String> = []
        for portName in module.outputs.keys {
            module.outputs[portName]!.gates
                .removeAll(where: { invalidOutputGates.contains($0) })
            if module.outputs[portName]!.gates.isEmpty {
                eliminatedOutputPorts.insert(portName)
            }
        }
        for portName in eliminatedOutputPorts {
            module.outputs.removeValue(forKey: portName)
        }

        syncClock(&module)
    }
}
