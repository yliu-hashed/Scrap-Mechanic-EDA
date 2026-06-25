//
//  YS Errors.swift
//  Scrap Mechanic EDA
//

enum TransformError: Error, CustomStringConvertible {
    case malformedCellPorts(cellName: String, description: String = "")
    case duplicateOutput(connId: UInt64, cellName1: String, cellName2: String)
    case connectionDoesNotExist(connId: UInt64)
    case invalidCellType(cellName: String, cellTypeName: String)

    var description: String {
        switch self {
        case .malformedCellPorts(let cellName, let description):
            return "The connections of cell '\(cellName)' is malformed. \(description)"
        case .duplicateOutput(let connId, let cellName1, let cellName2):
            return "Connection \(connId) cannot be the target of both cell '\(cellName1)' and '\(cellName2)'."
        case .connectionDoesNotExist(let connId):
            return "Connection \(connId) does not exist"
        case .invalidCellType(let cellName, let cellTypeName):
            return "Cell '\(cellName)' with type '\(cellTypeName)' is unsupported"
        }
    }
}

enum ModuleSelectionError: Error, CustomStringConvertible {
    case noTopLevelModule
    case missingClockDomain(name: String)
    case clockIsBus(name: String)
    case clockHasLogic(name: String)

    var description: String {
        switch self {
        case .noTopLevelModule:
            return "Unable to find any top level module."
        case .missingClockDomain(let name):
            return "Clock domain '\(name)' does not exist."
        case .clockIsBus(let name):
            return "Clock input '\(name)' cannot be a multi-width bus."
        case .clockHasLogic(let name):
            return "Clock domain '\(name)' has suspicious combinational logic."
        }
    }
}
