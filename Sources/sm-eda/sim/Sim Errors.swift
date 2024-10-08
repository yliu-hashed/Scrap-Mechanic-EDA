//
//  Sim Errors.swift
//  Scrap Mechanic EDA
//

import Foundation

enum REPLError: Error, CustomStringConvertible {
    case invalidCommand

    var description: String {
        switch self {
            case .invalidCommand:
                return "Invalid Command"
        }
    }
}
