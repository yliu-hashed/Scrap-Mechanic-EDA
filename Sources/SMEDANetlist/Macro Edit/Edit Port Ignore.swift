//
//  Edit Port Ignore.swift
//  Scrap Mechanic EDA
//

func editPortIgnore(
    _ mainModule: inout SMModule,
    port: EditPort,
    invalidOutputGates: inout Set<UInt64>
) throws {
    guard let gateIds = mainModule.outputs[port.port]?.gates else {
        throw EditError.noOutputPort(port: port.port)
    }
    for i in 0..<port.width {
        // ignore it
        let index = port.lsb + i
        let gateId = gateIds[index]
        invalidOutputGates.insert(gateId)
    }
}
