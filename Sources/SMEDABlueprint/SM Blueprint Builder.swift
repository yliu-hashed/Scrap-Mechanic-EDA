//
//  SM Blueprint Builder.swift
//  Scrap Mechanic EDA
//

private let kSMShapeID_logicGate = "9f0f56e8-2c31-4d83-996c-d00a9b296c3f"
private let kSMShapeID_timer     = "8f7fd0e7-c46e-4944-a414-7ce2437bb30f"
private let kSMShapeID_switch    = "7cf717d7-d167-4f2d-a6e7-6b2c70aa3986"
private let kSMShapeID_button    = "1e8d93a4-506b-470d-9ada-9c0a321e2db5"
private let kSMShapeID_cardboard = "f0cba95b-2dc4-4492-8fd9-36546a4cb5aa"
private let kSMShapeID_spaceship = "027bd4ec-b16d-47d2-8756-e18dc2af3eb6"
private let kSMShapeId_caution   = "09ca2713-28ee-4119-9622-e85490034758"

public class SMBlueprintBuilder {
    private var controllerIdCounter: UInt64 = 0
    public private(set) var blueprintBody: SMBlueprintBody

    public init(body: SMBlueprintBody = SMBlueprintBody()) {
        self.controllerIdCounter = 0
        self.blueprintBody = body
    }

    private var controllerIndex: [UInt64: Int] = [:]

    private func newControllerId() -> UInt64 {
        let controllerId = controllerIdCounter
        controllerIdCounter += 1
        return controllerId
    }

    /// Returns controller ID of the gate
    @discardableResult
    public func addGate(type: Int, position: SMVector, rotation: SMRotation?, color: SMColor?) -> UInt64 {
        let controllerId = newControllerId()
        let newController = SMBPController(
            active: false,
            id: controllerId,
            joints: nil,
            mode: type
        )
        let newChild = SMBlueprintItem(
            color: color?.hex,
            pos: position + (rotation?.compensation ?? .zero),
            shapeId: kSMShapeID_logicGate,
            xaxis: rotation?.alignX,
            zaxis: rotation?.alignZ,
            controller: newController
        )
        controllerIndex[controllerId] = blueprintBody.childs.endIndex
        blueprintBody.childs.append(newChild)

        return controllerId
    }

    @discardableResult
    public func addTimer(delay: Int, position: SMVector, rotation: SMRotation?, color: SMColor?) -> UInt64 {
        let controllerId = newControllerId()
        let newController = SMBPController(
            active: false,
            id: controllerId,
            joints: nil,
            seconds: delay / 40,
            ticks: delay % 40
        )
        let newChild = SMBlueprintItem(
            color: color?.hex,
            pos: position + (rotation?.compensation ?? .zero),
            shapeId: kSMShapeID_timer,
            xaxis: rotation?.alignX,
            zaxis: rotation?.alignZ,
            controller: newController
        )
        controllerIndex[controllerId] = blueprintBody.childs.endIndex
        blueprintBody.childs.append(newChild)
        return controllerId
    }

    public func addBlock(type: SMBlockType, position: SMVector, bounds: SMVector, color: SMColor? = nil) {

        let newChild = SMBlueprintItem(
            bounds: bounds,
            color: color?.hex,
            pos: position,
            shapeId: type.shapeID,
            xaxis: nil,
            zaxis: nil,
            controller: nil
        )

        blueprintBody.childs.append(newChild)
    }

    /// Returns controller ID of the device
    @discardableResult
    public func addDevice(position: SMVector, rotation: SMRotation, color: SMColor, device: SMInputDevice) -> UInt64 {
        let controllerId = newControllerId()

        let newController = SMBPController(active: false, id: controllerId, joints: nil)

        let shapeId: String
        switch device {
            case .button:
                shapeId = kSMShapeID_button
            case .switch:
                shapeId = kSMShapeID_switch
        }

        let newChild = SMBlueprintItem(
            color: color.hex,
            pos: position + rotation.compensation,
            shapeId: shapeId,
            xaxis: rotation.alignX,
            zaxis: rotation.alignZ,
            controller: newController
        )

        controllerIndex[controllerId] = blueprintBody.childs.endIndex
        blueprintBody.childs.append(newChild)

        return controllerId
    }

    public func appendControllers(_ newControllers: some Collection<UInt64>, to targetControllerId: UInt64) {
        guard !newControllers.isEmpty else { return }

        let index = controllerIndex[targetControllerId]!
        let newControllerItems = newControllers.map { SMBPControllerItem(id: $0) }

        let newCount = blueprintBody.childs[index].controller!.controllers?.count ?? 0 + newControllerItems.count
        if newCount > SMBlueprint.controllerLimit {
            print("Warning: controller \(targetControllerId) will have \(newCount) controllees")
        }

        if blueprintBody.childs[index].controller!.controllers == nil {
            blueprintBody.childs[index].controller!.controllers = []
        }
        blueprintBody.childs[index].controller!.controllers!.append(contentsOf: newControllerItems)
    }

    public func getControllerCount(of targetId: UInt64) -> Int {
        let index = controllerIndex[targetId]!
        return blueprintBody.childs[index].controller?.controllers?.count ?? 0
    }
}

public enum SMInputDevice: String, Codable, CaseIterable {
    case button = "button"
    case `switch` = "switch"
}

public enum SMBlockType: String {
    case cardboard = "cardboard"
    case spaceship = "spaceship"
    case caution   = "caution"

    var shapeID: String {
        switch self {
            case .cardboard:
                return kSMShapeID_cardboard
            case .spaceship:
                return kSMShapeID_spaceship
            case .caution:
                return kSMShapeId_caution
        }
    }
}
