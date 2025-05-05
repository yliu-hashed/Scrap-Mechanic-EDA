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

public enum EditCommand {
    indirect case merge(target: SMModule)
    case connect(route: EditPortRoute)
    case share(route: EditPortRoute)
    case drive(drive: EditPortDrive)
    case remove(port: EditPort)
    case solidify
}

public struct EditFunction {
    public let commands: [EditCommand]
    public let force: Bool

    public init(
        commands: consuming [EditCommand],
        force: Bool = false
    ) {
        self.commands = commands
        self.force = force
    }

    public func run(_ module: inout SMModule) throws {
        var invalidInputGates: Set<UInt64> = []
        var invalidOutputGates: Set<UInt64> = []
        func solidifyPorts() {
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
            invalidInputGates.removeAll()
            invalidOutputGates.removeAll()
        }

        for command in commands {
            switch command {
                case .merge(let target):
                    try editMerge(&module, with: target)
                case .connect(let route):
                    try editPortConnect(&module, route: route, invalidInputGates: &invalidInputGates)
                case .share(let route):
                    try editPortShare(&module, route: route, invalidInputGates: &invalidInputGates)
                case .drive(let drive):
                    try editPortDrive(&module, drive: drive, invalidInputGates: &invalidInputGates)
                case .remove(let port):
                    try editPortIgnore(&module, port: port, invalidOutputGates: &invalidOutputGates)
                case .solidify:
                    solidifyPorts()
            }
        }

        solidifyPorts()

        syncClock(&module)
    }
}
