//
//  Print Level.swift
//  Scrap Mechanic EDA
//

import ArgumentParser

enum PrintLevel: EnumerableFlag {
    case verbose
    case lite
    case none

    static func name(for value: PrintLevel) -> NameSpecification {
        switch value {
            case .verbose:
                return [.customLong("print-verbose"), .customShort("v")]
            case .lite:
                return [.customLong("print-lite")]
            case .none:
                return [.customLong("print-none"), .customLong("quiet"), .customShort("q")]
        }
    }
}
