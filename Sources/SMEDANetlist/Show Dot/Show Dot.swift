//
//  Show Dot.swift
//  Scrap Mechanic EDA
//

private extension SMGateType {
    func getDotName() -> String {
        switch self {
            case .logic(let type):
                switch type {
                    case .and:  return "AND"
                    case .or:   return "OR"
                    case .xor:  return "XOR"
                    case .nand: return "NAND"
                    case .nor:  return "NOR"
                    case .xnor: return "XNOR"
                }
            case .timer(let delay):
                return "TIMER(\(delay))"
        }
    }
}

public func showDot(module: borrowing SMModule, showID: Bool) -> String {
    var string: String = ""
    string += "digraph \"\(module.name)\" {\n"
    string += "  label=\"\(module.name)\";\n"
    string += "  rankdir=\"LR\";\n"
    string += "  remincross=true;\n"

    // dump gates
    for (gateId, gate) in module.gates {
        let isSequential = module.sequentialNodes.contains(gateId)
        var name = gate.type.getDotName()
        if showID { name += "[\(gateId)]" }
        let color = isSequential ? "royalblue" : "black"
        string += "  n\(gateId) [ shape=record, fontcolor=\(color), label=\"\(name)\" ];\n"
    }
    // dump connections
    for (dstId, gate) in module.gates {
        for srcId in gate.srcs {
            string += "  n\(srcId) -> n\(dstId)\n"
        }
    }
    // dump portals
    for (dstId, gate) in module.gates {
        for (srcId, depth) in gate.portalSrcs {
            string += "  n\(srcId) -> n\(dstId) [ style=dashed, color=forestgreen, label=\"\(depth)\" ];\n"
        }
    }
    // dump ports
    for (index, (portName, port)) in module.inputs.enumerated() {
        for (i, gateId) in port.gates.enumerated() {
            string += "  i\(index)_\(i) [ style=filled, color=gray label=\"\(portName)\\n\(i)/\(port.gates.count)\" ];\n"
            string += "  i\(index)_\(i) -> n\(gateId) [ style=dashed ];\n"
        }
    }
    for (index, (portName, port)) in module.outputs.enumerated() {
        for (i, gateId) in port.gates.enumerated() {
            string += "  o\(index)_\(i) [ style=filled, color=gray, label=\"\(portName)\\n\(i)/\(port.gates.count)\" ];\n"
            string += "  n\(gateId) -> o\(index)_\(i) [ style=dashed ];\n"
        }
    }
    string += "}"
    return string
}
