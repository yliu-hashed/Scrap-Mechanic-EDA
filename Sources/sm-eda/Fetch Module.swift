//
//  Fetch Module.swift
//  Scrap Mechanic EDA
//

import Foundation
import SMEDANetlist

func fetchModule(file: String) throws -> SMModule {
    let mergeSourceURL = URL(fileURLWithPath: file, isDirectory: false)
    let decoder = JSONDecoder()
    // read and parse netlist
    let mergeData = try Data(contentsOf: mergeSourceURL)
    return try decoder.decode(SMModule.self, from: mergeData)
}

func fetchModule(files: [String]) throws -> [SMModule] {
    var modules: [SMModule] = []
    var mergeNameTable: [String: String] = [:]
    for file in files {
        let module = try fetchModule(file: file)
        guard !mergeNameTable.keys.contains(module.name) else {
            let oldPath = mergeNameTable[module.name]!
            print("Warning: Skipping module \(module.name) from \(file). Module of the same name already exist in \(oldPath).")
            continue
        }
        mergeNameTable[module.name] = file
        modules.append(module)
    }
    return modules
}
