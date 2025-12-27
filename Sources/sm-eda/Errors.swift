//
//  Errors.swift
//  Scrap Mechanic EDA
//

enum CommandError: Error, CustomStringConvertible {
    case invalidFormat(path: String)
    case invalidInput(description: String)
    case lz4CannotBeAccessed(path: String)

    var description: String {
        switch self {
            case .invalidFormat(let path):
                return "File \"\(path)\" is not in the correct format"
            case .invalidInput(let description):
                return "Invalid Input: \(description)"
            case .lz4CannotBeAccessed(let path):
                return "The specified path to LZ4 \(path) cannot be read"
        }
    }
}
