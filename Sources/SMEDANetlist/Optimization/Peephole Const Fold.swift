//
//  Peephole Const Fold.swift
//  Scrap Mechanic EDA
//

@discardableResult
public func peepoptConstFold(builder: SMNetBuilder, keeping: borrowing Set<UInt64>) -> Bool {

    let oldCount = builder.module.gates.count

    var redrives: [UInt64: Bool] = [:]

    while true {
        // try to fold until cannot anymore
        let changed = constFoldPass(builder: builder, keeping: keeping, redrives: &redrives)
        if !changed { break }
    }

    // redrive high-drives
    let highDriver = builder.defered {
        let dummy = builder.addLogic(type: .or)
        let inv = builder.addLogic(type: .nor)
        builder.connect(dummy, to: inv)
        return inv
    }

    let lowDriver = builder.defered {
        return builder.addLogic(type: .or)
    }

    for (gateId, drive) in redrives {
        if drive {
            builder.connect(highDriver.use(), to: gateId)
        } else {
            builder.connect(lowDriver.use(), to: gateId)
        }
    }

    // count up results
    let newCount = builder.module.gates.count
    let changeCount = oldCount - newCount
    return changeCount > 0
}

private func constFoldPass(
    builder: SMNetBuilder,
    keeping: borrowing Set<UInt64>,
    redrives: inout [UInt64: Bool]
) -> Bool {

    let gatesOfIntrest = Set(builder.module.gates.keys).subtracting(keeping)
    var changed = false

    // propagate constant value for gates with no input
    for gateId in gatesOfIntrest {
        guard let gate = builder.module.gates[gateId] else { continue }
        if gate.srcs.isEmpty && !gate.dsts.isEmpty {
            eliminateConstDrive(builder: builder, from: gateId, keeping: keeping, redrives: &redrives)
            changed = true
        }
    }

    // purge gate with no output until stable
    while true {
        var stable = true
        for gateId in gatesOfIntrest {
            guard let gate = builder.module.gates[gateId] else { continue }
            if gate.dsts.isEmpty {
                builder.removeGate(gateId)
                stable = false
                changed = true
            }
        }
        if stable { break }
    }

    return changed
}

/// Propagate constant value into a drive tree and delete connections
private func eliminateConstDrive(builder: SMNetBuilder,
                                 from gateId: UInt64,
                                 keeping: borrowing Set<UInt64>,
                                 redrives: inout [UInt64: Bool]) {
    struct StackFrame {
        var gateId: UInt64
        var drive: Bool?
    }

    var stack: [StackFrame] = [StackFrame(gateId: gateId, drive: nil)]

    while let currentFrame = stack.last {
        let gate = builder.module.gates[currentFrame.gateId]!
        // if current gate has many inputs other than the constant drive (now removed)
        if !gate.srcs.isEmpty {
            guard let drive = currentFrame.drive,
                  case .logic(let logicType) = gate.type 
            else { fatalError() }

            // get what happens if the current gate is driven
            let resolution = driveGate(gateType: logicType, drive: drive)
            if case .convert(let type) = resolution {
                // constant drive does nothing, keep gate function in place
                builder.changeGateType(of: currentFrame.gateId, to: .logic(type: type))
                stack.removeLast()
                continue
            } else if case .dominate(let state) = resolution {
                // constant drive dominate input, current gate become constant
                // update current frame to resolve it
                builder.disconnect(gate.srcs, to: currentFrame.gateId)
                builder.changeGateType(of: currentFrame.gateId, to: .logic(type: .or))
                stack[stack.count-1].drive = state
                continue
            }
        }

        assert(gate.srcs.isEmpty)

        if let dstId = gate.dsts.first {
            // go down the frame for next gate to drive
            builder.disconnect(currentFrame.gateId, to: dstId)
            // obtain output state of current gate
            let newState: Bool
            if let drive = currentFrame.drive {
                if case .logic(let logicType) = gate.type {
                    newState = drive != logicType.isInverter
                } else { // timer
                    newState = drive
                }
            } else {
                newState = false
            }
            // go down the fame
            let newFrame = StackFrame(gateId: dstId, drive: newState)
            stack.append(newFrame)
        } else {
            // go up the frame if all children are resolved
            // for any keeping gate, they have to be redriven
            if keeping.contains(currentFrame.gateId) {
                assert(!redrives.keys.contains(currentFrame.gateId))
                redrives[currentFrame.gateId] = currentFrame.drive
            }
            // go up the frame
            stack.removeLast()
        }
    }
}

private enum DriveResolution {
    case convert(type: SMLogicType)
    case dominate(state: Bool)
}

/// Get what happens if you drive a multi-input logic gate
private func driveGate(gateType: SMLogicType, drive: Bool) -> DriveResolution {
    switch gateType.sourceAggrigationType {
        case .logicalAnd:
            // if driven by false, AND produce false, output is whether it is inverter
            return !drive ? .dominate(state: gateType.isInverter) : .convert(type: gateType)
        case .logicalOr:
            // if driven by true, OR produce true, output is whether it's not inverter
            return drive ? .dominate(state: !gateType.isInverter) : .convert(type: gateType)
        case .logicalChain:
            // if driven by true, XOR or XNOR is negated
            return .convert(type: drive ? gateType.negatedGate : gateType)
    }
}
