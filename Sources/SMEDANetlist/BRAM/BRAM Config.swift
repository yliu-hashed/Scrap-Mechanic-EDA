//
//  BRAM Config.swift
//  Scrap Mechanic EDA
//

public enum BRAMPortConfig: String, CaseIterable {
    case readWrite = "rw"
    case readOnly  = "r"
    case writeOnly = "w"

    public var hasRead: Bool { self != .writeOnly }
    public var hasWrite: Bool { self != .readOnly }
}
