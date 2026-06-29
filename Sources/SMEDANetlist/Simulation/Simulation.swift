//
//  Simulation.swift
//  Scrap Mechanic EDA
//

import Foundation

public class SimulationModel {
    public let module: SMModule
    internal private(set) var states: [UInt64: LogicState]
    internal private(set) var overrideList: [UInt64: Bool]

    public private(set) var instableCount: Int = 0
    public private(set) var isInstable: Bool = true
    public private(set) var willChange: Bool = false

    internal private(set) var recordingTime: UInt64 = 0
    internal private(set) var history: [LevelChangeRecord] = []
    private var recordingGateSet: Set<UInt64>
    private var recordingState: [UInt64: Bool]? = nil

    struct LevelChangeRecord {
        var time: UInt64
        var levelChanges: [UInt64: Bool]
    }

    enum LogicState: Equatable {
        case basic(Bool)
        case timer([UInt64])
    }

    public init(module: SMModule) {
        self.module = module

        states = [:]
        overrideList = [:]
        recordingGateSet = []

        buildState()
        buildOverrideList()
        buildRecordingGateSet()
    }

    func buildState() {
        states = Dictionary(uniqueKeysWithValues: module.gates.map { (gateId, gate) in
            switch gate.type {
            case .logic(_):
                return (gateId, .basic(false))
            case .timer(_):
                return (gateId, .timer([]))
            }
        })
        instableCount = 0
        isInstable = true
        willChange = true
    }

    func buildOverrideList() {
        var newOverrideList: [UInt64: Bool] = [:]
        for (_, port) in module.inputs {
            for gate in port.gates {
                newOverrideList[gate] = false
            }
        }
        overrideList = newOverrideList
        willChange = true
    }

    func buildRecordingGateSet() {
        var recordingGateSet: Set<UInt64> = []
        for port in module.inputs.values {
            recordingGateSet.formUnion(port.gates)
        }
        for port in module.outputs.values {
            recordingGateSet.formUnion(port.gates)
        }
        self.recordingGateSet = recordingGateSet
    }

    public func output(of id: UInt64) -> Bool {
        if let overrideState = overrideList[id] {
            return overrideState
        }
        switch states[id]! {
        case .basic(let basicState):
            return basicState
        case .timer(let timerState):
            guard case .timer(let delay) = module.gates[id]?.type else {
                preconditionFailure("Impossible")
            }
            return timerStateGetValue(state: timerState, delay: delay)
        }
    }

    public func override(_ gateId: UInt64, to value: Bool) {
        overrideList[gateId] = value
        willChange = true
    }

    public func resetAll() {
        buildState()
        buildOverrideList()
    }

    public func resetOverrides() {
        buildOverrideList()
    }

    public func resetInternal() {
        buildState()
    }

    public func wrapToStable(time: TimeInterval) -> Bool {
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < time {
            tick()
            if !isInstable { break }
        }
        return !isInstable
    }

    public func wrapToStable(ticks: Int) -> Bool {
        for _ in 0..<ticks {
            tick()
            if !isInstable { break }
        }
        return !isInstable
    }

    public func tick() {
        defer { updateRecording() }
        guard willChange || isInstable else {
            return
        }

        willChange = false

        var newStates: [UInt64: LogicState] = [:]
        // update
        for (gateId, gate) in module.gates {
            switch gate.type {
            case .logic(let logicType):
                let newState: Bool

                if let overrideState = overrideList[gateId] {
                    // use overriden if present
                    newState = overrideState
                } else {
                    // solve state
                    func evalAsOR() -> Bool {
                        for src in gate.srcs {
                            // if one is true, out is true
                            if output(of: src) {
                                return true
                            }
                        }
                        return false
                    }

                    func evalAsAND() -> Bool {
                        for src in gate.srcs {
                            // if one is false, out is false
                            if !output(of: src) {
                                return false
                            }
                        }
                        return true
                    }

                    func evalAsXOR() -> Bool {
                        var tmp = false
                        for src in gate.srcs {
                            if output(of: src) {
                                tmp = !tmp
                            }
                        }
                        return tmp
                    }

                    let notEmpty = !gate.srcs.isEmpty

                    switch logicType {
                    case .or:
                        newState = notEmpty && evalAsOR()
                    case .and:
                        newState = notEmpty && evalAsAND()
                    case .nor:
                        newState = notEmpty && !evalAsOR()
                    case .nand:
                        newState = notEmpty && !evalAsAND()
                    case .xor:
                        newState = notEmpty && evalAsXOR()
                    case .xnor:
                        newState = notEmpty && !evalAsXOR()
                    }
                }
                newStates[gateId] = .basic(newState)
            case .timer(let delay):
                guard case .timer(let timerState) = states[gateId] else { preconditionFailure() }
                let value: Bool
                if let gateId = gate.srcs.first {
                    value = output(of: gateId)
                } else {
                    value = false
                }
                let newState = timerStateTick(state: timerState, delay: delay, newValue: value)
                newStates[gateId] = .timer(newState)
            }
        }

        let isSame = states == newStates
        states = newStates

        if !isSame {
            if isInstable {
                instableCount += 1
            } else {
                instableCount = 1
            }
        }
        isInstable = !isSame
    }

    public func beginRecording() {
        history = []
        recordingTime = 0
        // build start frame
        var levelChanges: [UInt64: Bool] = [:]
        for gateId in recordingGateSet {
            let value = output(of: gateId)
            levelChanges[gateId] = value
        }
        let frame = LevelChangeRecord(time: 0, levelChanges: levelChanges)
        recordingState = levelChanges
        history.append(frame)
    }

    public func stopRecording() {
        recordingState = nil
    }

    func updateRecording() {
        // return if not recording
        guard recordingState != nil else { return }

        recordingTime += 1
        var levelChanges: [UInt64: Bool] = [:]
        for gateId in recordingGateSet {
            let oldValue = recordingState![gateId]!
            let newValue = output(of: gateId)
            if oldValue != newValue { levelChanges[gateId] = newValue }
            recordingState![gateId] = newValue
        }
        // return if no value changed
        guard !levelChanges.isEmpty else { return }

        let frame = LevelChangeRecord(time: recordingTime, levelChanges: levelChanges)
        history.append(frame)
    }
}

private func timerStateTick(state: [UInt64], delay: Int, newValue: Bool) -> [UInt64] {
    let bitCount = delay + 1
    let intCount = (bitCount + 64 - 1) / 64
    var newState = [UInt64](repeating: 0, count: intCount)
    var nextBit: Bool = newValue
    for i in 0..<intCount {
        let oldInt: UInt64
        if i >= 0, i < state.count {
            oldInt = state[i]
        } else {
            oldInt = 0
        }
        newState[i] = (oldInt >> 1) | (nextBit ? 0x8000000000000000 : 0)
        nextBit = (oldInt & 1) > 0
    }
    return newState
}

private func timerStateGetValue(state: [UInt64], delay: Int) -> Bool {
    let intIndex = delay / 64
    let bitIndex = delay % 64
    if state.indices.contains(intIndex) {
        return (state[intIndex] & (0x8000000000000000 >> bitIndex)) > 0
    } else {
        return false
    }
}

