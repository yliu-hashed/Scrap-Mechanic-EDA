//
//  Auto Plan Size.swift
//  Scrap Mechanic EDA
//

import ArgumentParser

struct AutoPlanSize: Equatable {
    var width: Int
    var depth: Int
    var height: Int

    var volume: Int {
        return width * depth * height
    }
}

extension AutoPlanSize: ExpressibleByArgument, CustomStringConvertible {
    var description: String {
        return "\(width)x\(depth)x\(height)"
    }
    
    public init?(argument: String) {
        let matchSizeRegex = #/(\d+)x(\d+)x(\d+)/#

        guard let match = try? matchSizeRegex.wholeMatch(in: argument)
        else { return nil }

        guard let w = Int(match.output.1),
              let d = Int(match.output.2),
              let h = Int(match.output.3)
        else { return nil }

        width = w
        depth = d
        height = h
    }
}
