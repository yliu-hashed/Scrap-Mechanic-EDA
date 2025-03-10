//
//  SM Module.swift
//  Scrap Mechanic EDA
//

public let kSMFrameTime: Double = 0.025
public let kSMFrameRate: Double = 40

/// A SM abstract gate network
public struct SMModule: Codable {

    public static let gateOutputLimit: Int = 256

    /// The name of the module
    public var name: String
    /// The gates that's contained in the module
    public var gates: [UInt64: SMGate]
    /// The gates that are part of the sequential circuit. This is for record keeping only. Used to
    /// facilitate timing analysis.
    public var sequentialNodes: Set<UInt64>
    /// The input ports and the gates that made up them
    public var inputs: [String: Port]
    /// The output ports and the gates that made up them
    public var outputs: [String: Port]

    public var colorHex: String?

    public struct Port: Codable {
        public var gates: [UInt64]
        public var isClock: Bool

        public var colorHex: String?
        public var device: String?

        public init(gates: [UInt64], isClock: Bool = false, colorHex: String? = nil, device: String? = nil) {
            self.gates = gates
            self.isClock = isClock
            self.colorHex = colorHex
            self.device = device
        }

        enum CodingKeys: CodingKey {
            case gates
            case isClock
            case color
            case device
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            gates = try container.decode([UInt64].self, forKey: CodingKeys.gates)
            isClock = try container.decodeIfPresent(Bool.self, forKey: CodingKeys.isClock) ?? false
            colorHex = try container.decodeIfPresent(String.self, forKey: CodingKeys.color)
            device = try container.decodeIfPresent(String.self, forKey: CodingKeys.device)
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.gates, forKey: CodingKeys.gates)
            if isClock { try container.encode(self.isClock, forKey: CodingKeys.isClock) }
            try container.encodeIfPresent(self.colorHex, forKey: CodingKeys.color)
            try container.encodeIfPresent(self.device, forKey: CodingKeys.device)
        }
    }

    public init(
        name: String,
        gates: [UInt64 : SMGate],
        cycleGates: Set<UInt64>,
        inputs: [String : Port],
        outputs: [String : Port],
        colorHex: String?
    ) {
        self.name = name
        self.gates = gates
        self.sequentialNodes = cycleGates
        self.inputs = inputs
        self.outputs = outputs
        self.colorHex = colorHex
    }

    public var isEmpty: Bool {
        gates.isEmpty
    }

    public init() {
        name = "Untitled"
        gates = [:]
        sequentialNodes = []
        inputs = [:]
        outputs = [:]
        colorHex = nil
    }

    public func calcConnectionCount() -> Int {
        var connCount: Int = 0
        for (_, gate) in gates {
            connCount += gate.srcs.count
        }
        return connCount
    }

    public func nextId() -> UInt64 {
        if let maxId = gates.keys.max() {
            return maxId + 1
        } else {
            return 0
        }
    }
}

extension SMLogicType {

    /// Whether the gate is a inverter if only one input is given
    public var isInverter: Bool {
        switch self {
            case .or,  .and,  .xor:  return false
            case .nor, .nand, .xnor: return true
        }
    }

    /// The behavior of the gate when treating multiple input sources
    public var sourceAggrigationType: SourceAggrigationType {
        switch self {
            case .or,  .nor:  return .logicalOr
            case .and, .nand: return .logicalAnd
            case .xor, .xnor: return .logicalChain
        }
    }

    /// The negated gate type to the current gate
    public var negatedGate: SMLogicType {
        switch self {
            case .or:   return .nor
            case .and:  return .nand
            case .nor:  return .or
            case .nand: return .and
            case .xor:  return .xnor
            case .xnor: return .xor
        }
    }

    /// Evaluate if a gate type is logically equiavalent to another gate under a given input count
    public func isLogicallyEquiv(to other: SMLogicType, inputCount: Int) -> Bool {
        if inputCount == 0 {
            // all gates are low with no input
            return true
        } else if inputCount == 1 {
            // all gates are inverters or buffers with 1 input
            return isInverter == other.isInverter
        } else {
            // compare directly for gate with 2 or more input
            return self == other
        }
    }

    /// Evaluate if a gate type is logically negation to another gate under a given input count
    public func isLogicallyOpposite(to other: SMLogicType, inputCount: Int) -> Bool {
        if inputCount == 0 {
            // all gates are low with no input
            return false
        } else if inputCount == 1 {
            // all gates are inverters or buffers with 1 input
            return isInverter != other.isInverter
        } else {
            // compare directly for gate with 2 or more input
            return (sourceAggrigationType == other.sourceAggrigationType) && (isInverter != other.isInverter)
        }
    }
}

/// The characteristic of a gate at processing its input
public enum SourceAggrigationType: Int {
    case logicalAnd
    case logicalOr
    case logicalChain

    /// the equivalent front part of the gate
    public var equivGate: SMLogicType {
        switch self {
            case .logicalAnd:   return .and
            case .logicalOr:    return .or
            case .logicalChain: return .xor
        }
    }
}
