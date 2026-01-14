//
//  Sim Errors.swift
//  Scrap Mechanic EDA
//

enum REPLError: Error, CustomStringConvertible {
    case invalidCommand

    var description: String {
        switch self {
        case .invalidCommand:
            return "Invalid Command"
        }
    }
}
