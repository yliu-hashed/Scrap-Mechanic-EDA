//
//  Sim VCD Gen.swift
//  Scrap Mechanic EDA
//

import Foundation
import SMEDANetlist

struct LevelChangeRecord {
    var time: UInt64
    var levelChanges: [UInt64: Bool]
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = .init(identifier: "en_US_POSIX")
    formatter.dateFormat = "EEE MMM d ss:mm:HH YYYY"
    return formatter
}()

func vcdGen(module: borrowing SMModule, duration: UInt64, history: borrowing [LevelChangeRecord]) -> String {
    // obtain date information
    let date = Date()
    let dateString = dateFormatter.string(from: date)
    // header - metadata
    var string: String = ""
    string += "$version\n  sm-net-sim\n$end\n"
    string += "$date\n  \(dateString)\n$end\n"
    string += "$timescale\n  1ns\n$end\n"
    // header - variables
    string += "$scope module TOP $end\n"
    // emit inputs
    string += "  $scope module INPUTS $end\n"
    var inputLookup: [Int: String] = [:]
    for (index, (name, gates)) in module.inputs.enumerated() {
        inputLookup[index] = name
        let width = gates.gates.count
        let fullName = width == 0 ? name : "\(name)[\(width - 1):0]"
        string += "    $var wire \(width) I\(index) \(fullName) $end\n"
    }
    string += "  $upscope $end\n"
    // emit outptus
    string += "  $scope module OUTPUTS $end\n"
    var outputLookup: [Int: String] = [:]
    for (index, (name, gates)) in module.outputs.enumerated() {
        outputLookup[index] = name
        let width = gates.gates.count
        let fullName = width == 0 ? name : "\(name)[\(width - 1):0]"
        string += "    $var wire \(width) O\(index) \(fullName) $end\n"
    }
    string += "  $upscope $end\n"
    string += "$upscope $end\n"
    string += "$enddefinitions $end\n"
    // data section
    var states: [UInt64: Bool] = [:]
    for (_, record) in history.enumerated() {
        string += "#\(record.time)\n"
        // states
        for (gateId, state) in record.levelChanges {
            states[gateId] = state
        }
        // get which input and output is changed, based on which gate is changed
        var changedInputIndices: Set<Int> = []
        for (index, name) in inputLookup {
            let gates = module.inputs[name]!.gates
            for gateId in gates {
                if record.levelChanges.keys.contains(gateId) {
                    changedInputIndices.insert(index)
                }
            }
        }
        var changedOutputIndices: Set<Int> = []
        for (index, name) in outputLookup {
            let gates = module.outputs[name]!.gates
            for gateId in gates {
                if record.levelChanges.keys.contains(gateId) {
                    changedOutputIndices.insert(index)
                }
            }
        }
        // obtain the bits for changed inputs and outputs
        for (index, name) in inputLookup where changedInputIndices.contains(index) {
            let gates = module.inputs[name]!.gates
            var bits: String = "b"
            for gateId in gates.reversed() {
                let state = states[gateId]!
                bits += state ? "1" : "0"
            }
            string += "\(bits) I\(index)\n"
        }
        for (index, name) in outputLookup where changedOutputIndices.contains(index) {
            let gates = module.outputs[name]!.gates
            var bits: String = "b"
            for gateId in gates.reversed() {
                let state = states[gateId]!
                bits += state ? "1" : "0"
            }
            string += "\(bits) O\(index)\n"
        }
    }
    string += "#\(duration)\n"
    return string
}
