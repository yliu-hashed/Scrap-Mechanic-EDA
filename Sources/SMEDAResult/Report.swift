//
//  Report.swift
//  Scrap Mechenic EDA
//

import Foundation

public struct FullSynthesisReport: Codable {
    public var complexityReport: ComplexityReport = ComplexityReport()
    public var timingReport: TimingReport = TimingReport()
    public var placementReport: PlacementReport = PlacementReport()

    public init() {}

    enum CodingKeys: String, CodingKey {
        case complexityReport = "complexity_report"
        case timingReport = "timing_report"
        case placementReport = "placement_report"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.complexityReport = try container.decode(ComplexityReport.self, forKey: .complexityReport)
        self.timingReport = try container.decode(TimingReport.self, forKey: .timingReport)
        self.placementReport = try container.decode(PlacementReport.self, forKey: .placementReport)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.complexityReport, forKey: .complexityReport)
        try container.encode(self.timingReport, forKey: .timingReport)
        try container.encode(self.placementReport, forKey: .placementReport)
    }
}

public struct ComplexityReport: Codable {
    public var gateCount: Int = 0
    public var inputGateCount: Int = 0
    public var outputGateCount: Int = 0
    public var internalGateCount: Int = 0

    public var sequentialGateCount: Int = 0
    public var combinationalGateCount: Int = 0

    public var connectionCount: Int = 0
    public var averageGateInputCount: Float = 0

    public init() {}

    enum CodingKeys: String, CodingKey {
        case gateCount = "gate_count"
        case inputGateCount = "in_gate_count"
        case outputGateCount = "out_gate_count"
        case internalGateCount = "internal_gate_count"
        case sequentialGateCount = "seq_gate_count"
        case combinationalGateCount = "comb_gate_count"
        case connectionCount = "conn_count"
        case averageGateInputCount = "avg_gate_count"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.gateCount = try container.decode(Int.self, forKey: .gateCount)
        self.inputGateCount = try container.decode(Int.self, forKey: .inputGateCount)
        self.outputGateCount = try container.decode(Int.self, forKey: .outputGateCount)
        self.internalGateCount = try container.decode(Int.self, forKey: .internalGateCount)
        self.sequentialGateCount = try container.decode(Int.self, forKey: .sequentialGateCount)
        self.combinationalGateCount = try container.decode(Int.self, forKey: .combinationalGateCount)
        self.connectionCount = try container.decode(Int.self, forKey: .connectionCount)
        self.averageGateInputCount = try container.decode(Float.self, forKey: .averageGateInputCount)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.gateCount, forKey: .gateCount)
        try container.encode(self.inputGateCount, forKey: .inputGateCount)
        try container.encode(self.outputGateCount, forKey: .outputGateCount)
        try container.encode(self.internalGateCount, forKey: .internalGateCount)
        try container.encode(self.sequentialGateCount, forKey: .sequentialGateCount)
        try container.encode(self.combinationalGateCount, forKey: .combinationalGateCount)
        try container.encode(self.connectionCount, forKey: .connectionCount)
        try container.encode(self.averageGateInputCount, forKey: .averageGateInputCount)
    }
}

public struct TimingReport: Codable {
    public var criticalDepth: Int? = nil
    public var timingType: TimingType? = nil
    public var inputTiming: [String: Int] = [:]
    public var outputTiming: [String: Int] = [:]

    public init() {}

    enum CodingKeys: String, CodingKey {
        case criticalDepth = "crit_depth"
        case timingType = "timing_type"
        case inputTiming = "input_depth"
        case outputTiming = "output_depth"
    }

    public enum TimingType: String, Codable {
        case combinational
        case sequential
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.criticalDepth = try container.decodeIfPresent(Int.self, forKey: .criticalDepth)
        self.timingType = try container.decodeIfPresent(TimingType.self, forKey: .timingType)
        self.inputTiming = try container.decode([String : Int].self, forKey: .inputTiming)
        self.outputTiming = try container.decode([String : Int].self, forKey: .outputTiming)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(self.criticalDepth, forKey: .criticalDepth)
        try container.encodeIfPresent(self.timingType, forKey: .timingType)
        try container.encode(self.inputTiming, forKey: .inputTiming)
        try container.encode(self.outputTiming, forKey: .outputTiming)
    }
}

public struct PlacementReport: Codable {
    public typealias PortLine = [PortSegment]
    public typealias PortSurface = [PortLine]

    public struct PortSegment: Codable {
        public var name: String
        public var lsb: Int
        public var msb: Int
        public var offset: Int

        public init(name: String, lsb: Int, msb: Int, offset: Int) {
            self.name = name
            self.lsb = lsb
            self.msb = msb
            self.offset = offset
        }

        enum CodingKeys: String, CodingKey {
            case name = "name"
            case lsb = "lsb"
            case msb = "msb"
            case offset = "offset"
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decode(String.self, forKey: .name)
            self.lsb = try container.decode(Int.self, forKey: .lsb)
            self.msb = try container.decode(Int.self, forKey: .msb)
            self.offset = try container.decode(Int.self, forKey: .offset)
        }

        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.name, forKey: .name)
            try container.encode(self.lsb, forKey: .lsb)
            try container.encode(self.msb, forKey: .msb)
            try container.encode(self.offset, forKey: .offset)
        }
    }

    public var width: Int = 0
    public var depth: Int = 0
    public var height: Int = 0

    public var utilization: Float = 0
    public var conservativeUtilization: Float = 0

    public var surfaces: [String: PortSurface] = [:]

    public init() {}

    enum CodingKeys: String, CodingKey {
        case surfaces = "surfaces"
        case width = "width"
        case depth = "depth"
        case height = "height"
        case utilization = "utilization"
        case conservativeUtilization = "conservative_utilization"
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.width = try container.decode(Int.self, forKey: .width)
        self.depth = try container.decode(Int.self, forKey: .depth)
        self.height = try container.decode(Int.self, forKey: .height)
        self.surfaces = try container.decode([String: PortSurface].self, forKey: .surfaces)
        self.utilization = try container.decode(Float.self, forKey: .utilization)
        self.conservativeUtilization = try container.decode(Float.self, forKey: .conservativeUtilization)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.width, forKey: .width)
        try container.encode(self.depth, forKey: .depth)
        try container.encode(self.height, forKey: .height)
        try container.encode(self.surfaces, forKey: .surfaces)
        try container.encode(self.utilization, forKey: .utilization)
        try container.encode(self.conservativeUtilization, forKey: .conservativeUtilization)
    }
}
