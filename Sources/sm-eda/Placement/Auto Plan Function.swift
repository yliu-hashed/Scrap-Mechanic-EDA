//
//  Auto Plan Function.swift
//  Scrap Mechanic EDA
//

import ArgumentParser
import SMEDANetlist
import SMEDABlueprint

private let kBPSizesArgHelp = ArgumentHelp(
    "The sizes of the blueprint to attempt",
    discussion: "This specifies the sizes of the blueprint to try in the notation '<width>x<depth>x<height>' (like 10x10x20). This option is mutually exclusive with '--depth' and '--width'. You can specify multiple sizes by providing multiple arguments. The first one that fits the design will be chosen. If no sizes are given, automatic placement guided optionally by '--depth' and '--width' will be done.",
    valueName: "sizes"
)

private let kBPWidthArgHelp = ArgumentHelp(
    "The width to wrap the ports of the blueprint",
    discussion: "This specifies the maximum width of the blueprint. If no value is given, the maximum width of any port clamped to 16 will be used as the width of the module.",
    valueName: "width"
)

private let kBPDepthArgHelp = ArgumentHelp(
    "The depth of the blueprint",
    discussion: "This specifies the depth of the blueprint. If no value is given, a depth no larger than 32 that results in height that cover all ports is used.",
    valueName: "depth"
)

private let kNoFacadeArgHelp = ArgumentHelp(
    "Do not generate a facade for the blueprint",
    discussion: "This option disables the generation of gates with random orientation. Facade is used to make the blueprint look better, but it may make the design bigger (in utilization).",
    valueName: "no-facade"
)

private let kInputDeviceArgHelp = ArgumentHelp(
    "The input device connected to the gate",
    discussion: "This sets the default input device for the blueprint. The input device type attribute overrides this property on a per-port level. Use Yosys design attribute '(* device = \"switch/button/none\" *)' or SM Module attribute 'i_port_device.PORT_NAME' with value 'switch/button/none' to specify per-port device.",
    valueName: "device"
)

private let kPortDoubleSidedArgHelp = ArgumentHelp(
    "The location of the ports of the blueprint",
    discussion: "Ports can be placed in the front only, or in both the front and back.",
    valueName: "port-double-sided"
)

private let kPackPortArgHelp = ArgumentHelp(
    "Pack port freely instead of alphabetically",
    discussion: "This option makes the port faces smaller.",
    valueName: "pack-port"
)

private let kSinkPortArgHelp = ArgumentHelp(
    "Sink the ports to be flush with the body",
    discussion: "This option makes the faces flush, but makes the module harder to connect using the in-game connection tool.",
    valueName: "sink-port"
)

private enum PlaceInputDevice: EnumerableFlag {
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

struct AutoPlanArgGroup: ParsableArguments {
    @Option(name: [.customShort("s"), .customLong("size")], help: kBPSizesArgHelp)
    var sizes: [AutoPlanSize] = []

    @Option(name: [.customShort("d"), .customLong("depth")], help: kBPDepthArgHelp)
    var blueprintDepth: Int? = nil

    @Option(name: [.customShort("w"), .customLong("width")], help: kBPWidthArgHelp)
    var blueprintWidth: Int? = nil

    @Flag(exclusivity: .exclusive, help: kInputDeviceArgHelp)
    private var inputDeviceType: PlaceInputDevice = .none

    @Flag(name: [.customLong("no-facade")], help: kNoFacadeArgHelp)
    var noFacade: Bool = false

    @Flag(name: [.customLong("double-sided")], help: kPortDoubleSidedArgHelp)
    var portDoubleSided: Bool = false

    @Flag(name: [.customLong("pack")], help: kPackPortArgHelp)
    var packPort: Bool = false

    @Flag(name: [.customLong("sink")], help: kSinkPortArgHelp)
    var sinkPort: Bool = false

    func validate() throws {
        if sizes.count > 0 {
            guard blueprintDepth == nil else {
                throw ValidationError.redundantDepth
            }
            guard blueprintWidth == nil else {
                throw ValidationError.redundantWidth
            }
        }
        if let depth = blueprintDepth {
            guard depth >= 1 else {
                throw ValidationError.nonPositiveDepth
            }
        }
        if let width = blueprintWidth {
            guard width >= 1 else {
                throw ValidationError.nonPositiveWidth
            }
        }
    }

    enum ValidationError: Error, CustomStringConvertible {
        case nonPositiveDepth
        case nonPositiveWidth
        case redundantDepth
        case redundantWidth

        var description: String {
            switch self {
                case .nonPositiveDepth:
                    return "Depth must be a positive integer."
                case .nonPositiveWidth:
                    return "Width must be a positive integer."
                case .redundantDepth:
                    return "Depth must not be specified when volumes are used"
                case .redundantWidth:
                    return "Width must not be specified when volumes are used"
            }
        }
    }

    func work(module: borrowing SMModule) throws -> PlacementConfig {
        let sizing: AutoPlanSizing = if sizes.isEmpty {
            .automatic(width: blueprintWidth, depth: blueprintDepth)
        } else {
            .specific(sizes: sizes)
        }

        return autoPlan(
            for: module,
            sizing: sizing,
            device: inputDeviceType.device,
            noFacade: noFacade,
            portDoubleSided: portDoubleSided,
            packPort: packPort,
            sinkPort: sinkPort
        )
    }
}
