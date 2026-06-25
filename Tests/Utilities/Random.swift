//
//  Random.swift
//  Scrap Mechanic EDA
//

/// A simple deterministic random number generator
struct SimpleRandomGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64 = 1) {
        state = seed == 0 ? 1 : seed
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 17
        state ^= state << 5
        return state
    }
}
