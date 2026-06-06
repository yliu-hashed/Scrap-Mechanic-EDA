//
//  CNF Builder.swift
//  Scrap Mechanic EDA
//

/// Generic CNF builder
class CNFBuilder {
    public private(set) var clauses: String = ""
    public private(set) var variableCount: Int = 0
    public private(set) var clauseCount: Int = 0

    var header: String {
        return "p cnf \(variableCount) \(clauseCount)\n"
    }

    enum Literal: Equatable, Hashable, ExpressibleByBooleanLiteral {
        typealias BooleanLiteralType = Bool

        case regular(index: Int)
        case constant(Bool)

        static prefix func !(_ rhs: Literal) -> Literal {
            switch rhs {
            case .regular(let index):
                return .regular(index: -index)
            case .constant(let value):
                return .constant(!value)
            }
        }

        init(booleanLiteral value: Bool) {
            self = .constant(value)
        }
    }

    func addVariable() -> Literal {
        variableCount += 1
        return .regular(index: variableCount)
    }

    func addClause(_ vars: Literal...) {
        if vars.contains(true) { return }
        for v in vars {
            // skip over any constant false
            guard case .regular(let index) = v else { continue }
            clauses += "\(index) "
        }
        clauses += "0\n"
        clauseCount += 1
    }

    func addClause(_ vars: [Literal]) {
        if vars.contains(true) { return }
        for v in vars {
            guard case .regular(let index) = v else { continue }
            clauses += "\(index) "
        }
        clauses += "0\n"
        clauseCount += 1
    }

    func addAND(_ inputs: [Literal], matching output: Literal) {
        precondition(inputs.count > 0)
        var bigClause: [Literal] = [output]
        for input in inputs {
            bigClause.append(!input)
            addClause(input, !output)
        }
        addClause(bigClause)
    }

    func addOR(_ inputs: [Literal], matching output: Literal) {
        precondition(inputs.count > 0)
        var bigClause: [Literal] = [!output]
        for input in inputs {
            bigClause.append(input)
            addClause([!input, output])
        }
        addClause(bigClause)
    }

    func addXOR(_ inputs: [Literal], matching output: Literal) {
        precondition(inputs.count > 0)
        guard inputs.count > 1 else {
            addEqual(inputs.first!, to: output)
            return
        }
        addXORHelper(.init(inputs), matching: output)
    }

    private func addXORHelper(_ inputs: ArraySlice<Literal>, matching output: Literal) {
        precondition(inputs.count >= 2)
        let mid = inputs.count / 2
        let lhsInputs = inputs.prefix(mid)
        let rhsInputs = inputs.suffix(inputs.count - mid)

        let lhs: Literal
        if lhsInputs.count == 1 {
            lhs = lhsInputs.first!
        } else {
            lhs = addVariable()
            addXORHelper(lhsInputs, matching: lhs)
        }

        var rhs: Literal
        if rhsInputs.count == 1 {
            rhs = rhsInputs.first!
        } else {
            rhs = addVariable()
            addXORHelper(rhsInputs, matching: rhs)
        }

        addClause( lhs, !rhs,  output)
        addClause(!lhs, !rhs, !output)
        addClause( lhs,  rhs, !output)
        addClause(!lhs,  rhs,  output)
    }

    func addImply(_ input: Literal, to value: Literal) {
        addClause([!input, value])
    }

    func addForce(_ input: Literal, to value: Bool) {
        if value {
            addClause(input)
        } else {
            addClause(!input)
        }
    }

    func addEqual(_ input: Literal, to other: Literal) {
        addClause(!input, other)
        addClause(input, !other)
    }

    func addEqual(_ input: Literal, to other: Literal, if condition: Literal) {
        addClause(!input, other, !condition)
        addClause(input, !other, !condition)
    }

    func addMutex(_ inputs: [Literal]) {
        addClause(inputs)
        for i in inputs.indices {
            for j in 0..<i {
                addClause(!inputs[i], !inputs[j])
            }
        }
    }

    func addMux(_ s: Literal, `true` t: Literal, `false` f: Literal, matching output: Literal) {
        addClause(!t, output, !s)
        addClause( t,!output, !s)
        addClause(!f, output,  s)
        addClause( f,!output,  s)
    }
}
