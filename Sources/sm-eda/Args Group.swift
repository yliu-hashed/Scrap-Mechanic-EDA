//
//  Arg Group.swift
//  Scrap Mechanic EDA
//

import ArgumentParser
import SMEDABlueprint

struct PlacementArgGroup: ParsableArguments {
    @Option(name: [.customLong("depth")], help: kBPDepthArgHelp)
    var blueprintDepth: Int? = nil

    @Option(name: [.customLong("width")], help: kBPWidthArgHelp)
    var blueprintWidth: Int? = nil

    @Flag(exclusivity: .exclusive, help: kInputDeviceArgHelp)
    var inputDeviceType: PlaceInputDevice = .switch

    @Flag(name: [.customLong("no-facade")], help: kNoFacadeArgHelp)
    var noFacade: Bool = false

    @Flag(exclusivity: .exclusive, help: kPortLocationArgHelp)
    var portLocation: SimplePlacementEngine.PortLocation = .bothSide

    @Flag(name: [.customLong("pack")], help: kPackPortArgHelp)
    var packPort: Bool = false

    @Option(name: [.customLong("lz4-path")], help: kLZ4PathArgHelp)
    var lz4Path: String? = nil
}

struct TransformArgGroup: ParsableArguments {
    @Flag(name: [.customLong("no-opt")])
    var noOptimize: Bool = false

    @Option(name: [.customLong("clk")], help: kClockDomainArgHelp)
    var clockDomainNames: [String] = []
}


extension SimplePlacementEngine.PortLocation: EnumerableFlag {
    static func name(for value: SimplePlacementEngine.PortLocation) -> NameSpecification {
        switch value {
            case .bothSide:
                return [.customLong("pb"), .customLong("port-both-side")]
            case .front:
                return [.customLong("pf"), .customLong("port-front-only")]
        }
    }
}

enum PlaceInputDevice: EnumerableFlag {
    case button
    case `switch`
    case none

    static func name(for value: PlaceInputDevice) -> NameSpecification {
        switch value {
            case .button:
                return [.customLong("in-button"), .customLong("btn")]
            case .switch:
                return [.customLong("in-switch"), .customLong("sw")]
            case .none:
                return [.customLong("in-none"), .customLong("inn")]
        }
    }

    var device: SMInputDevice? {
        switch self {
            case .button:
                return .button
            case .switch:
                return .switch
            case .none:
                return nil
        }
    }
}
