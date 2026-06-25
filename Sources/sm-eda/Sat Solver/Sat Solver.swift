//
//  Sat Solver.swift
//  Scrap Mechanic EDA
//

import Subprocess
#if canImport(System)
import System
#else
import SystemPackage
#endif

extension CNFBuilder {

    private enum SATResult: Sendable {
        case sat([UInt64: Bool])
        case unsat
    }

    enum SATError: Error, Sendable, CustomStringConvertible {
        case solverError(exitCode: Int32)
        case terminated(code: Int32)

        var description: String {
            switch self {
            case .solverError(let exitCode):
                return "Solver exited with non-standard exit code \(exitCode)."
            case .terminated(let code):
                return "Solver is terminated with exit code \(code)."
            }
        }
    }

    struct Assignments {
        fileprivate var values: [UInt64: Bool] = [:]

        var count: Int { values.count }

        subscript(_ variable: Literal) -> Bool? {
            switch variable {
            case .regular(let index):
                let variable = UInt64(abs(index))
                guard let value = values[variable] else { return nil }
                return index < 0 ? !value : value
            case .constant(let bool):
                return bool
            }
        }
    }

    static let defaultSATSolver = "kissat"

    func solve(using solverPath: String? = nil) async throws -> Assignments? {
        let executable: Executable
        if let solverPath = solverPath {
            executable = .path(.init(solverPath))
        } else {
            executable = .name(Self.defaultSATSolver)
        }

        let result = try await run(
            executable,
            arguments: [],
            input: .inputWriter,
            output: .sequence,
            error: .discarded
        ) { execution in
            let writer = execution.standardInputWriter
            _ = try await writer.write(header)
            _ = try await writer.write(clauses)
            try await writer.finish()
            let parser = SATResultParser()
            for try await chunk in execution.standardOutput {
                parser.ingest(chunk: chunk.bytes)
            }
            parser.finalize()
            return parser.assignments
        }

        switch result.terminationStatus {
        case .exited(10):
            return Assignments(values: result.closureOutput)
        case .exited(20):
            return nil
        case .exited(let code):
            throw SATError.solverError(exitCode: code)
        case .signaled(let code):
            throw SATError.terminated(code: code)
        }
    }
}

fileprivate class SATResultParser {
    func ingest(chunk: RawSpan) {
        for offset in chunk.byteOffsets {
            let byte = chunk.unsafeLoad(fromByteOffset: offset, as: UInt8.self)
            guard byte != 0 && byte <= 128 else { continue }
            parse(character: Character(UnicodeScalar(byte)))
        }
    }

    enum ParserState {
        case atStartOfLine
        case seekEndOfLine
        case seekVariable
        case parsingVariable
    }

    private var state: ParserState = .atStartOfLine
    private var hasNegation: Bool = false
    private var partial: UInt64 = 0

    internal private(set) var assignments: [UInt64: Bool] = [:]

    private func stopVariableIfNeeded() {
        guard state == .parsingVariable else { return }
        if partial >= 0 {
            assignments[partial] = !hasNegation
        }
        partial = 0
        hasNegation = false
    }

    private func parse(character: Character) {
        guard !character.isNewline else {
            stopVariableIfNeeded()
            state = .atStartOfLine
            return
        }
        switch state {
        case .atStartOfLine:
            if character.isWhitespace { return }
            switch character {
            case "v":
                state = .seekVariable
                return
            case "c", "s":
                state = .seekEndOfLine
                return
            default:
                break
            }
        case .seekEndOfLine:
            return
        case .seekVariable:
            if character.isWhitespace { return }
            if character == "-" {
                hasNegation = true
                state = .parsingVariable
                return
            }
            if character.isWholeNumber {
                let digit = UInt64(String(character)) ?? 0
                partial = partial * 10 + digit
                state = .parsingVariable
                return
            }
        case .parsingVariable:
            if character.isWholeNumber {
                let digit = UInt64(String(character)) ?? 0
                partial = partial * 10 + digit
                return
            }
            if character.isWhitespace {
                stopVariableIfNeeded()
                state = .seekVariable
                return
            }
        }

        print(for: .warning, "Solver parsor encountered bad input character '\(character)'. This line will not be parsed.")
        stopVariableIfNeeded()
        state = .seekEndOfLine
    }

    func finalize() {
        stopVariableIfNeeded()
    }
}
