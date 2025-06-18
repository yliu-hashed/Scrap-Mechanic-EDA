//
//  Bram Command.swift
//  Scrap Mechanic EDA
//

import Foundation
import ArgumentParser
import SMEDANetlist

private let portConfigArgHelp = ArgumentHelp(
    "Input and output ports of the memory.",
    discussion: "Supports w, r, and rw for writeonly, readonly, and read-write. Please specify ports in order using multiple arguments. Only one writing port is supported."
)

private let dbitsDiscussion = """
This argument specifies the number of bits at each address.
Range:
  TIMER : 1...128
  DFF   : 1...256
"""

private let dbitsArgHelp = ArgumentHelp(
    "The addressability of the memory.",
    discussion: dbitsDiscussion,
    valueName: "data-bits"
)

private let abitsDiscussion = """
This argument specifies the number of bits of an address.
Range:
  TIMER : 2...16
  DFF   : 1...8
"""

private let abitsArgHelp = ArgumentHelp(
    "Address space of the memory, in powers of two.",
    discussion: abitsDiscussion,
    valueName: "addr-bits"
)

private let multiplexityDiscussion = "This argument is only valid on TIMER memory. This argument specifies the number of parallel timers for a given addressable bit in power of two. Higher number is larger, but have lower delay. Must be higher than 0 and lower than address space - 2."

private let multiplexityArgHelp = ArgumentHelp(
    "The multiplicity of the internal TIMER layout.",
    discussion: multiplexityDiscussion,
    valueName: "multiplex-bits"
)

private let maxLoopLengthDiscussion = "When specified, the program will increase multiplexity until the loop length is below this target. This value must be bigger or equal to 4."

private let maxLoopLengthArgHelp = ArgumentHelp(
    "The delay target in ticks for automatically choosing multiplexity of timer memory.",
    discussion: maxLoopLengthDiscussion,
    valueName: "ticks"
)

struct BRAMCMD: ParsableCommand {
    static var configuration: CommandConfiguration {
        CommandConfiguration(commandName: "bram", discussion: "Generate memory using timer or XOR DFFs.")
    }

    @Flag(exclusivity: .exclusive, help: "The amount of information to print to the console")
    var printlevel: PrintLevel = .lite

    @Flag(exclusivity: .exclusive, help: "The type of memory to generate")
    var type: MemoryType

    @Option(name: [.customShort("p"), .customLong("port")],
            help: portConfigArgHelp)
    var ports: [BRAMPortConfig] = [.readWrite]

    @Option(name: [.customShort("d"), .customLong("dbits"), .customLong("data-bits")],
            help: dbitsArgHelp)
    var dbits: Int = 8

    @Option(name: [.customShort("a"), .customLong("abits"), .customLong("addr-bits")],
            help: abitsArgHelp)
    var abits: Int

    @Option(name: [.customShort("m"), .customLong("mbits"), .customLong("mult-bits")],
            help: multiplexityArgHelp)
    var multiplexity: Int = 0

    @Option(name: [.customLong("max-loop-delay")], help: maxLoopLengthArgHelp)
    var maxLoopDelayTarget: Int? = nil

    @Option(name: [.customShort("n"), .customLong("name")],
            help: "Rename the output module")
    var name: String = "Untitled"

    @OptionGroup(title: "Store Module")
    var storeModuleOptions: StoreModuleArgGroup

    mutating func run() throws {
        // guard against port misconfiguration
        guard ports.contains(where: { $0.hasRead }) else {
            throw CommandError.invalidInput(description: "No read ports configured")
        }

        guard ports.contains(where: { $0.hasWrite }) else {
            throw CommandError.invalidInput(description: "No write ports configured")
        }

        guard type == .dff || ports.lazy.filter({ $0.hasWrite }).count == 1 else {
            throw CommandError.invalidInput(description: "Cannot have more than one write port for TIMER memory")
        }

        // guard against invalid arguments
        let abitsMax = type == .dff ?   8 :  16
        let abitsMin = type == .dff ?   1 :   2

        let dbitsMax = type == .dff ? 256 : 128

        guard dbits > 0, dbits <= dbitsMax else {
            throw CommandError.invalidInput(description: "Addressability (dbits) must be in the range of 1...\(dbitsMax) for \(type) memory")
        }

        guard abits >= abitsMin, abits <= abitsMax else {
            throw CommandError.invalidInput(description: "Address space (abits) must be in the range of \(abitsMin)...\(dbitsMax) for \(type) memory")
        }

        guard multiplexity >= 0 else {
            throw CommandError.invalidInput(description: "Multiplexity cannot be negative")
        }

        guard multiplexity <= 7 else {
            throw CommandError.invalidInput(description: "Multiplexity cannot be bigger than 2^7")
        }

        if let maxLoopDelayTarget = maxLoopDelayTarget {
            if type == .timer {
                guard maxLoopDelayTarget >= 4 else {
                    throw CommandError.invalidInput(description: "Maximum loop delay cannot be less than 4")
                }
                let maxLoopP2 = Int.bitWidth - (maxLoopDelayTarget - 1).leadingZeroBitCount
                let targetMultiplexityP2 = abits - maxLoopP2
                if targetMultiplexityP2 > 7 {
                    print("WARNING: Maximum loop delay of \(maxLoopDelayTarget) cannot achieved as more than 2^7 of multiplexity is required.")
                    multiplexity = 7
                } else {
                    multiplexity = max(multiplexity, targetMultiplexityP2)
                }
            } else if printlevel != .none {
                print("WARNING: Maximum loop delay argument is only supported for timer memory.")
            }
        }

        guard type == .dff || abits - multiplexity >= 2 else {
            throw CommandError.invalidInput(description: "Address space must be 4 times larger than multiplexity.")
        }

        // create coders
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys

        // generate
        var module: SMModule
        switch type {
            case .dff:
                let config = BRAMDFFConfig(
                    addressability: dbits,
                    addressSpacePow2: abits,
                    ports: ports
                )
                module = genBRAMDFF(config: config)
            case .timer:
                let config = BRAMTimerConfig(
                    addressability: dbits,
                    addressSpacePow2: abits,
                    multiplexityPow2: multiplexity,
                    ports: ports
                )
                module = genBRAMTimer(config: config)
                if printlevel != .none {
                    print("timer cycle: \(config.timerCycleLength)(\(config.timerCycleLengthS)s)")
                }
        }

        try module.check()
        module.name = name

        if printlevel != .none {
            print("\(module.gates.count) gates generated")
        }

        // write
        try storeModuleOptions.work(module: module, printlevel: printlevel)
    }

    enum MemoryType: EnumerableFlag, CustomStringConvertible {
        case dff
        case timer

        static func name(for value: MemoryType) -> NameSpecification {
            switch value {
                case .dff:
                    return [.customLong("dff")]
                case .timer:
                    return [.customLong("timer")]
            }
        }

        var description: String {
            switch self {
                case .dff:
                    return "DFF"
                case .timer:
                    return "TIMER"
            }
        }
    }
}
