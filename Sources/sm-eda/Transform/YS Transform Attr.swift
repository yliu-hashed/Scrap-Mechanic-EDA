//
//  YS Transform Attr.swift
//  Scrap Mechanic EDA
//

import SMEDANetlist
import SMEDABlueprint

func transferAttributes(ysModule: YSModule, to smModule: inout SMModule) {
    recordColorToAttribute(ysModule: ysModule, smModule: &smModule)
    recordInputDeviceTypeToAttribute(ysModule: ysModule, smModule: &smModule)
}

func recordColorToAttribute(ysModule: YSModule, smModule: inout SMModule) {
    if let colorString = ysModule.attributes["color"] {
        if let color = extractColor(literal: colorString), color.validate() {
            smModule.colorHex = color.hex
        } else {
            print("Warning: module color literal \(colorString) is invalid. Using default color")
        }
    }

    for (portName, port) in ysModule.ports {
        guard let netName = ysModule.netNames[portName],
              netName.bits == port.bits,
              let colorString = netName.attributes["color"]
        else { continue }

        if let color = extractColor(literal: colorString), color.validate() {
            if port.direction == .input {
                smModule.inputs[portName]?.colorHex = color.hex
            } else {
                smModule.inputs[portName]?.colorHex = color.hex
            }
        } else {
            print("Warning: color literal \(colorString) for port \(portName) is invalid. Using default color")
        }
    }
}

func recordInputDeviceTypeToAttribute(ysModule: YSModule, smModule: inout SMModule) {
    for (portName, port) in ysModule.ports {
        guard let netName = ysModule.netNames[portName],
              netName.bits == port.bits,
              let deviceString = netName.attributes["device"]
        else { continue }


        let dev: String
        if deviceString == "none" {
            dev = "none"
        } else if let device = SMInputDevice(rawValue: deviceString) {
            dev = device.rawValue
        } else {
            print("Warning: module input device literal \(deviceString) is invalid. Using default device")
            continue
        }

        if port.direction == .input {
            smModule.inputs[portName]?.device = dev
        } else {
            smModule.inputs[portName]?.device = dev
        }
    }
}
