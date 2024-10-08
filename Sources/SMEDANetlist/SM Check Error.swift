//
//  SM Check Error.swift
//  Scrap Mechanic EDA
//

import Foundation

enum NetlistError: Error, CustomStringConvertible {
    case danglingGate(gateId: UInt64)
    case asymDst(gateId: UInt64, dstId: UInt64)
    case asymSrc(gateId: UInt64, srcId: UInt64)
    case twoCycle(gateId1: UInt64, gateId2: UInt64)
    case selfConnection(gateId: UInt64)

    case combPortal(gateId: UInt64)
    case asymPortalDst(gateId: UInt64, dstId: UInt64)
    case asymPortalSrc(gateId: UInt64, srcId: UInt64)

    case tooManyOutput(gateId: UInt64, count: Int)
    case timerManyInput(gateId: UInt64)

    var description: String {
        switch self {
            case .danglingGate(let gateId):
                return "Dangling gate \(gateId)"
            case .asymDst(let gateId, let dstId):
                return "Gate \(gateId) have destination \(dstId), but \(dstId) does not have \(gateId) as source"
            case .asymSrc(let gateId, let srcId):
                return "Gate \(gateId) have source \(srcId), but \(srcId) does not have \(gateId) as destination"
            case .twoCycle(let gateId1, let gateId2):
                return "Gate \(gateId1) and \(gateId2) form a two cycles"
            case .selfConnection(let gateId):
                return "Gate \(gateId) is connected to itself"
            case .combPortal(let gateId):
                return "Gate \(gateId) have portal, but it is not sequential"
            case .asymPortalDst(let gateId, let dstId):
                return "Gate \(gateId) have portal destination \(dstId), but \(dstId) does not have \(gateId) as portal source"
            case .asymPortalSrc(let gateId, let srcId):
                return "Gate \(gateId) have portal source \(srcId), but \(srcId) does not have \(gateId) as portal destination"
            case .tooManyOutput(let gateId, let count):
                return "Gate \(gateId) have \(count) output, over the limit of \(SMModule.gateOutputLimit)"
            case .timerManyInput(let gateId):
                return "Timer \(gateId) cannot have more than one input"
        }
    }
}
