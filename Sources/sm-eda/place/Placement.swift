//
//  Placement.swift
//  Scrap Mechanic EDA
//

import SMEDANetlist
import SMEDABlueprint
import SMEDAResult

extension SMBlueprintBuilder {
    @discardableResult
    func addGate(type: SMGateType, position: SMVector, rotation: SMRotation?, color: SMColor?) -> UInt64 {
        switch type {
            case .logic(let type):
                return addGate(type: type.rawValue, position: position, rotation: rotation, color: color)
            case .timer(let delay):
                return addTimer(delay: delay, position: position, rotation: rotation, color: color)
        }
    }
}

func simplePlace(
    _ module: SMModule, defaultInputDevice: SMInputDevice?,
    depth: Int?, widthWrap: Int?,
    portLocation: SimplePlacementEngine.PortLocation,
    packPort: Bool,
    facade: Bool,
    report: inout PlacementReport,
    doPrint: Bool
) throws -> SMBlueprint {

    let engine = SimplePlacementEngine(
        widthWrapping: widthWrap,
        depth: depth,
        facadeMode: facade,
        portLocation: portLocation,
        packPort: packPort
    )

    return try place(
        module,
        defaultInputDevice: defaultInputDevice,
        using: engine,
        report: &report,
        doPrint: doPrint
    )
}

func place(
    _ module: SMModule,
    defaultInputDevice: SMInputDevice?,
    using placementEngine: any PlacementEngine,
    report: inout PlacementReport,
    doPrint: Bool
) throws -> SMBlueprint {

    // Size Warning
    var connsCount: Int = 0
    for gate in module.gates.values {
        connsCount += gate.srcs.count
    }

    // Setup builder
    let builder = SMBlueprintBuilder()

    /// Record which gate has which controller. Controller id keyed by gate id.
    var controllerStore: [UInt64: UInt64] = [:]
    controllerStore.reserveCapacity(module.gates.count + module.inputs.count)

    // Calculate parameters for builder
    let sortedInputs  = module.inputs.sorted(by: { $0.key < $1.key })
    let sortedOutputs = module.outputs.sorted(by: { $0.key < $1.key })

    let inputBitCounts  = sortedInputs .map(\.value.gates.count)
    let outputBitCounts = sortedOutputs.map(\.value.gates.count)

    var internalGateCount = module.gates.count
    for bitCount in inputBitCounts {
        internalGateCount -= bitCount
    }
    for bitCount in outputBitCounts {
        internalGateCount -= bitCount
    }

    let timerCount = module.gates.lazy.filter { (_, value) in
        if case .timer(_) = value.type {
            return true
        }
        return false
    }.count
    let logicCount = internalGateCount - timerCount

    // Layout using builder
    try placementEngine.layout(
        inputs: inputBitCounts,
        outputs: outputBitCounts,
        logicCount: logicCount,
        timerCount: timerCount
    )

    // Place all input gates
    var inputPortNames = [String](repeating: "", count: sortedInputs.count)
    for (index, (portName, port)) in sortedInputs.enumerated() {
        // figure out color
        let color: SMColor
        if let colorName = port.colorHex {
            color = .custom(hex: colorName)
        } else {
            color = (index % 2 == 0) ? .defaultInputOdd : .defaultInputEven
        }

        // figure out device type
        let deviceType: SMInputDevice?
        if let deviceTypeName = port.device {
            if deviceTypeName == "none" {
                deviceType = nil
            } else {
                deviceType = SMInputDevice(rawValue: deviceTypeName)!
            }
        } else {
            deviceType = defaultInputDevice
        }

        // place
        for (gateIndex, gateId) in port.gates.enumerated() {
            let info = placementEngine.placeInputs(index: index, bit: gateIndex)

            let gate = module.gates[gateId]!
            let controllerId = builder.addGate(
                type: gate.type, position: info.pos,
                rotation: info.rot, color: color
            )
            controllerStore[gateId] = controllerId

            // place input device (switch or button)
            if let deviceType = deviceType {
                let deviceInfo = placementEngine.placeDeviceForInput(index: index, bit: gateIndex)
                let switchId = builder.addDevice(
                    position: deviceInfo.pos, rotation: deviceInfo.rot,
                    color: color, device: deviceType
                )
                builder.appendControllers([controllerId], to: switchId)
            }
        }

        inputPortNames[index] = portName
    }

    // Place all output gates
    var outputPortNames = [String](repeating: "", count: sortedOutputs.count)
    for (index, (portName, port)) in sortedOutputs.enumerated() {
        let color: SMColor
        if let colorName = port.colorHex {
            color = .custom(hex: colorName)
        } else {
            color = (index % 2 == 0) ? .defaultOutputOdd : .defaultOutputEven
        }
        for (gateIndex, gateId) in port.gates.enumerated() {
            let info = placementEngine.placeOutputs(index: index, bit: gateIndex)

            let gate = module.gates[gateId]!
            let controllerId = builder.addGate(
                type: gate.type, position: info.pos,
                rotation: info.rot, color: color
            )
            controllerStore[gateId] = controllerId
        }

        outputPortNames[index] = portName
    }

    // obtain internal gate color
    let bodyColor: SMColor
    if let colorName = module.colorHex {
        bodyColor = .custom(hex: colorName)
    } else {
        bodyColor = .defaultBodyGates
    }

    // place all internal gates
    for (gateId, gate) in module.gates where !controllerStore.keys.contains(gateId) {
        let info: PlacementInfo
        switch gate.type {
            case .logic(_): info = placementEngine.placeLogic()
            case .timer(_): info = placementEngine.placeTimer()
        }
        let controllerId = builder.addGate(
            type: gate.type, position: info.pos,
            rotation: info.isHidden ? nil : info.rot,
            color: info.isHidden ? nil : bodyColor
        )
        controllerStore[gateId] = controllerId
    }

    // connect all gates together
    for (gateId, gate) in module.gates {
        let targetController = controllerStore[gateId]!
        for sourceGateId in gate.srcs {
            let sourceController = controllerStore[sourceGateId]!
            builder.appendControllers([targetController], to: sourceController)
        }
    }

    // print the placed graph
    if doPrint { placementEngine.printPlaced(inputNames: inputPortNames, outputNames: outputPortNames) }
    report = placementEngine.reportPlaced(inputNames: inputPortNames, outputNames: outputPortNames)

    // emit blueprint
    return SMBlueprint(bodies: [builder.blueprintBody])
}

struct PlacementInfo {
    var pos: SMVector
    var rot: SMRotation
    var isHidden: Bool

    init(pos: SMVector, rot: SMRotation, isHidden: Bool = false) {
        self.pos = pos
        self.rot = rot
        self.isHidden = isHidden
    }
}

protocol PlacementEngine: AnyObject {
    /// Prime the placement engine for placement given port's bit sizes and internal gate count.
    /// Layout must be called before any place calls.
    func layout(inputs: [Int], outputs: [Int], logicCount: Int, timerCount: Int) throws

    func placeInputs(index: Int, bit: Int) -> PlacementInfo
    func placeOutputs(index: Int, bit: Int) -> PlacementInfo
    func placeLogic() -> PlacementInfo
    func placeTimer() -> PlacementInfo
    func placeDeviceForInput(index: Int, bit: Int) -> PlacementInfo

    func printPlaced(inputNames: [String], outputNames: [String])
    func reportPlaced(inputNames: [String], outputNames: [String]) -> PlacementReport
}
