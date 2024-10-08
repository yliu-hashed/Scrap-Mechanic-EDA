//
//  SM Blueprint.swift
//  Scrap Mechanic EDA
//

public struct SMBlueprint: Codable, Equatable {
    public static let controllerLimit: Int = 256
    public static let packetSizeLimit: Int = 524288

    var bodies: [SMBlueprintBody]
    var joints: [SMBPJoint]? = nil
    var version: Int = 4

    public init(bodies: [SMBlueprintBody] = []) {
        self.bodies = bodies
    }
}

public struct SMBlueprintBody: Codable, Equatable {
    var childs: [SMBlueprintItem]

    public init(childs: [SMBlueprintItem] = []) {
        self.childs = childs
    }
}

public struct SMBPJoint: Codable, Equatable {
    var childA: Int
    var childB: Int
    var color: String?
    var shapeId: String
    var controller: SMBPController?
    var id: Int
    var posA: SMVector
    var posB: SMVector
    var xaxisA: SMDirection
    var zaxisA: SMDirection
    var xaxisB: SMDirection
    var zaxisB: SMDirection
}

public struct SMBlueprintItem: Codable, Equatable {
    var bounds: SMVector?
    var color: String?
    var pos: SMVector
    var shapeId: String
    var xaxis: SMDirection?
    var zaxis: SMDirection?
    var controller: SMBPController?
    var joints: [SMBPItemJoint]?
}

public struct SMBPItemJoint: Codable, Equatable {
    var id: Int
}

public struct SMBPController: Codable, Equatable {
    var active: Bool?
    var controllers: [SMBPControllerItem]?
    var id: UInt64
    var joints: [SMBPControllerJoint]? = nil
    var mode: Int? = nil
    // timer specific
    var seconds: Int? = nil
    var ticks: Int? = nil
    // controller specific
    var playMode: Int? = nil
    var timePerFrame: Double? = nil
    // piston specific
    var length: Int? = nil
    var speed: Int? = nil
    // light specific
    var color: String? = nil
    var coneAngle: Int? = nil
    var luminance: Int? = nil

    public init(
        active: Bool? = nil,
        controllers: [SMBPControllerItem]? = nil,
        id: UInt64,
        joints: [SMBPControllerJoint]? = nil,
        mode: Int? = nil,
        seconds: Int? = nil,
        ticks: Int? = nil,
        playMode: Int? = nil,
        timePerFrame: Double? = nil,
        length: Int? = nil,
        speed: Int? = nil,
        color: String? = nil,
        coneAngle: Int? = nil,
        luminance: Int? = nil
    ) {
        self.active = active
        self.controllers = controllers
        self.id = id
        self.joints = joints
        self.mode = mode
        self.seconds = seconds
        self.ticks = ticks
        self.playMode = playMode
        self.timePerFrame = timePerFrame
        self.length = length
        self.speed = speed
        self.color = color
        self.coneAngle = coneAngle
        self.luminance = luminance
    }

    enum CodingKeys: CodingKey {
        case active
        case controllers
        case id
        case joints
        case mode
        case seconds
        case ticks
        case playMode
        case timePerFrame
        case length
        case speed
        case color
        case coneAngle
        case luminance
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.active = try container.decodeIfPresent(Bool.self, forKey: .active)
        self.controllers = try container.decodeIfPresent([SMBPControllerItem].self, forKey: .controllers)
        self.id = try container.decode(UInt64.self, forKey: .id)
        self.joints = try container.decodeIfPresent([SMBPControllerJoint].self, forKey: .joints)
        self.mode = try container.decodeIfPresent(Int.self, forKey: .mode)
        self.seconds = try container.decodeIfPresent(Int.self, forKey: .seconds)
        self.ticks = try container.decodeIfPresent(Int.self, forKey: .ticks)
        self.playMode = try container.decodeIfPresent(Int.self, forKey: .playMode)
        self.timePerFrame = try container.decodeIfPresent(Double.self, forKey: .timePerFrame)
        self.length = try container.decodeIfPresent(Int.self, forKey: .length)
        self.speed = try container.decodeIfPresent(Int.self, forKey: .speed)
        self.color = try container.decodeIfPresent(String.self, forKey: .color)
        self.coneAngle = try container.decodeIfPresent(Int.self, forKey: .coneAngle)
        self.luminance = try container.decodeIfPresent(Int.self, forKey: .luminance)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(self.active, forKey: .active)
        try container.encode(self.controllers, forKey: .controllers)
        try container.encode(self.id, forKey: .id)
        try container.encodeIfPresent(self.joints, forKey: .joints)
        try container.encodeIfPresent(self.mode, forKey: .mode)
        try container.encodeIfPresent(self.seconds, forKey: .seconds)
        try container.encodeIfPresent(self.ticks, forKey: .ticks)
        try container.encodeIfPresent(self.playMode, forKey: .playMode)
        try container.encodeIfPresent(self.timePerFrame, forKey: .timePerFrame)
        try container.encodeIfPresent(self.length, forKey: .length)
        try container.encodeIfPresent(self.speed, forKey: .speed)
        try container.encodeIfPresent(self.color, forKey: .color)
        try container.encodeIfPresent(self.coneAngle, forKey: .coneAngle)
        try container.encodeIfPresent(self.luminance, forKey: .luminance)
    }
}

public struct SMBPControllerJoint: Codable, Equatable {
    var endAngle: Int
    var startAngle: Int
    var frames: [TargetAngle]
    var id: Int
    var index: Int
    var reverse: Bool

    public struct TargetAngle: Codable, Equatable {
        var targetAngle: Int
    }
}

public struct SMBPControllerItem: Codable, Equatable {
    var frames: [FrameSetting]? = nil
    var index: Int? = nil
    var id: UInt64

    public struct FrameSetting: Codable, Equatable {
        var setting: Int
    }
}
