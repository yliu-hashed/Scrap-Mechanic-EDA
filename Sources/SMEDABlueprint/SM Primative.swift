//
//  SM Primative.swift
//  Scrap Mechanic EDA
//

import Foundation

private func mod<T: BinaryInteger>(_ x: T, _ y: T) -> T {
    let r = x % y
    return (r < 0) ? (r + y) : r
}

public struct SMVector: Codable, Equatable, Hashable {

    public var x: Int
    public var y: Int
    public var z: Int

    public var distance: Double {
        return sqrt(Double(x*x + y*y + z*z))
    }

    public var volume: Int {
        return x * y * z
    }

    public static func +(lhs: Self, rhs: Self) -> Self {
        return Self(x: lhs.x + rhs.x, y: lhs.y + rhs.y, z: lhs.z + rhs.z)
    }

    public static func -(lhs: Self, rhs: Self) -> Self {
        return Self(x: lhs.x - rhs.x, y: lhs.y - rhs.y, z: lhs.z - rhs.z)
    }

    public static prefix func -(rhs: Self) -> Self {
        return Self(x: -rhs.x, y: -rhs.y, z: -rhs.z)
    }

    public static func *(lhs: Self, rhs: Int) -> Self {
        return .init(x: lhs.x * rhs, y: lhs.y * rhs, z: lhs.z * rhs)
    }

    public static func *=(lhs: inout Self, rhs: Int) {
        lhs = lhs * rhs
    }

    public func cross(with other: Self) -> Self {
        let cx = y * other.z - z * other.y
        let cy = z * other.x - x * other.z
        let cz = x * other.y - y * other.x
        return SMVector(x: cx, y: cy, z: cz)
    }

    public func dot(with other: Self) -> Int {
        return x * other.x + y * other.y + z * other.z
    }

    public init(x: Int = 0, y: Int = 0, z: Int = 0) {
        self.x = x
        self.y = y
        self.z = z
    }

    public static var zero: Self { .init(x: 0, y: 0, z: 0) }
    public static var one: Self { .init(x: 1, y: 1, z: 1) }
}

public enum SMDirection: Int, Codable, CaseIterable {
    case posX =  1
    case posY =  2
    case posZ =  3
    case negX = -1
    case negY = -2
    case negZ = -3

    public init?(vector: SMVector) {
        guard vector != .zero else { return nil }

        switch (vector.x, vector.y, vector.z) {
            case (let x, 0, 0):
                self = x > 0 ? .posX : .negX
            case (0, let y, 0):
                self = y > 0 ? .posY : .negY
            case (0, 0, let z):
                self = z > 0 ? .posZ : .negZ
            default:
                return nil
        }
    }

    public var vector: SMVector {
        switch self {
            case .posX: return SMVector(x:  1, y:  0, z:  0)
            case .posY: return SMVector(x:  0, y:  1, z:  0)
            case .posZ: return SMVector(x:  0, y:  0, z:  1)
            case .negX: return SMVector(x: -1, y:  0, z:  0)
            case .negY: return SMVector(x:  0, y: -1, z:  0)
            case .negZ: return SMVector(x:  0, y:  0, z: -1)
        }
    }

    public var opposite: SMDirection {
        return SMDirection(rawValue: -rawValue)!
    }

    public func isPerpendicular(to other: SMDirection) -> Bool {
        return abs(self.rawValue) != abs(other.rawValue)
    }

    /// Rotate the direction around another direction by 90 degrees.
    /// Equavalent to the cross product of the two directions.
    public func rotated(around direction: SMDirection) -> SMDirection {
        guard isPerpendicular(to: direction) else { return self }

        let c = vector.cross(with: direction.vector)

        switch (c.x, c.y, c.z) {
            case ( 1,  0,  0): return .posX
            case ( 0,  1,  0): return .posY
            case ( 0,  0,  1): return .posZ
            case (-1,  0,  0): return .negX
            case ( 0, -1,  0): return .negY
            case ( 0,  0, -1): return .negZ
            default: fatalError()
        }
    }

    /// Rotate the direction around another direction by 90 degrees by a given number of times
    public func rotated(around direction: SMDirection, amount: Int) -> SMDirection {
        let a = mod(amount, 4)
        var direction: SMDirection = self
        for _ in 0..<a {
            direction = direction.rotated(around: direction)
        }
        return self
    }

    public static func random() -> SMDirection {
        let index = Int.random(in: 0..<6)
        switch index {
            case 0: return .posX
            case 1: return .posY
            case 2: return .posZ
            case 3: return .negX
            case 4: return .negY
            case 5: return .negZ
            default: fatalError()
        }
    }
}

public struct SMRotation: Equatable, Hashable {
    /// The direction that the shape's x axis aligns with
    public var alignX: SMDirection
    /// The direction that the shape's z axis aligns with
    public var alignZ: SMDirection

    public init(alignX: SMDirection, alignZ: SMDirection) {
        guard alignX.isPerpendicular(to: alignZ) else { fatalError() }
        self.alignX = alignX
        self.alignZ = alignZ
    }

    /// Obtain the rotation of a logic gate, button, or switch given the facing and pointing
    /// direction. For a logic gate, the pointing side is the gate's arrow, for a switch, the
    /// pointing direction is the side of the LEDs on the face of the switch.
    public static func device(facing face: SMDirection, pointing point: SMDirection) -> SMRotation {
        guard face.isPerpendicular(to: point) else { fatalError() }

        let gateAlignX = point
        let gateAlignZ = gateAlignX.rotated(around: face)
        return SMRotation(alignX: gateAlignX, alignZ: gateAlignZ)
    }

    public static func timer(pointing point: SMDirection) -> SMRotation {
        // timers is longer in the -y axis, pointing is in the -y axis
        // get any secondary direction perpendicular to pointing, they all look the same
        let xAlign: SMDirection = point.opposite.isPerpendicular(to: .posX) ? .posX : .posY
        let zAlign = point.opposite.rotated(around: xAlign)
        return SMRotation(alignX: xAlign, alignZ: zAlign)
    }

    /// Rotate the rotation around another direction by 90 degrees by a given number of times
    public func rotated(around direction: SMDirection, amount: Int) -> SMRotation {
        let newX = alignX.rotated(around: direction, amount: amount)
        let newZ = alignZ.rotated(around: direction, amount: amount)
        return SMRotation(alignX: newX, alignZ: newZ)
    }

    /// The facing direction of the face of the logic gate, button, or switch
    public var gateFacing: SMDirection {
        alignZ.rotated(around: alignX)
    }

    /// The pointing direction of the gate arrow of a logic gate, or the LED side of a switch.
    public var gatePointing: SMDirection {
        alignX
    }

    /// Positional compensation for the rotation
    public var compensation: SMVector {
        switch (alignX.rawValue, alignZ.rawValue) {
            case (-3, -2): return .init(x: 0, y: 1, z: 1)
            case (-3, -1): return .init(x: 1, y: 1, z: 1)
            case (-3,  1): return .init(x: 0, y: 0, z: 1)
            case (-3,  2): return .init(x: 1, y: 0, z: 1)
            case (-2, -3): return .init(x: 1, y: 1, z: 1)
            case (-2, -1): return .init(x: 1, y: 1, z: 0)
            case (-2,  1): return .init(x: 0, y: 1, z: 1)
            case (-2,  3): return .init(x: 0, y: 1, z: 0)
            case (-1, -3): return .init(x: 1, y: 0, z: 1)
            case (-1, -2): return .init(x: 1, y: 1, z: 1)
            case (-1,  2): return .init(x: 1, y: 0, z: 0)
            case (-1,  3): return .init(x: 1, y: 1, z: 0)
            case ( 1, -3): return .init(x: 0, y: 1, z: 1)
            case ( 1, -2): return .init(x: 0, y: 1, z: 0)
            case ( 1,  2): return .init(x: 0, y: 0, z: 1)
            case ( 1,  3): return .init(x: 0, y: 0, z: 0)
            case ( 2, -3): return .init(x: 0, y: 0, z: 1)
            case ( 2, -1): return .init(x: 1, y: 0, z: 1)
            case ( 2,  1): return .init(x: 0, y: 0, z: 0)
            case ( 2,  3): return .init(x: 1, y: 0, z: 0)
            case ( 3, -2): return .init(x: 1, y: 1, z: 0)
            case ( 3, -1): return .init(x: 1, y: 0, z: 0)
            case ( 3,  1): return .init(x: 0, y: 1, z: 0)
            case ( 3,  2): return .init(x: 0, y: 0, z: 0)
            default: fatalError()
        }
    }

    /// Angular rotation in (x, y, z) notated by the number of 90 degrees
    public var angularRotation: SMVector {
        switch (alignX.rawValue, alignZ.rawValue) {
            case (-3, -2): return .init(x: 1, y: 0, z: 3)
            case (-3, -1): return .init(x: 2, y: 3, z: 0)
            case (-3,  1): return .init(x: 1, y: 1, z: 3)
            case (-3,  2): return .init(x: 3, y: 0, z: 1)
            case (-2, -3): return .init(x: 2, y: 0, z: 1)
            case (-2, -1): return .init(x: 1, y: 3, z: 0)
            case (-2,  1): return .init(x: 0, y: 1, z: 3)
            case (-2,  3): return .init(x: 0, y: 0, z: 3)
            case (-1, -3): return .init(x: 2, y: 0, z: 2)
            case (-1, -2): return .init(x: 3, y: 2, z: 0)
            case (-1,  2): return .init(x: 1, y: 2, z: 0)
            case (-1,  3): return .init(x: 2, y: 2, z: 0)
            case ( 1, -3): return .init(x: 2, y: 0, z: 0)
            case ( 1, -2): return .init(x: 1, y: 0, z: 0)
            case ( 1,  2): return .init(x: 3, y: 0, z: 0)
            case ( 1,  3): return .init(x: 0, y: 0, z: 0)
            case ( 2, -3): return .init(x: 0, y: 2, z: 1)
            case ( 2, -1): return .init(x: 3, y: 3, z: 0)
            case ( 2,  1): return .init(x: 1, y: 1, z: 0)
            case ( 2,  3): return .init(x: 0, y: 0, z: 1)
            case ( 3, -2): return .init(x: 1, y: 0, z: 1)
            case ( 3, -1): return .init(x: 0, y: 3, z: 0)
            case ( 3,  1): return .init(x: 2, y: 1, z: 0)
            case ( 3,  2): return .init(x: 3, y: 0, z: 3)
            default: fatalError()
        }
    }

    // MARK: Values
    /// A standard rotation where x aligns with x, and z aligns with z
    public static let zero = SMRotation(alignX: .posX, alignZ: .posZ)

    public static func random() -> SMRotation {
        let firstIndex = Int.random(in: 0..<6)
        let firstAxis = SMDirection.allCases[firstIndex]

        let validSecondAxis = SMDirection.allCases.filter { $0.isPerpendicular(to: firstAxis) }
        let secondIndex = Int.random(in: 0..<4)
        let secondAxis = validSecondAxis[secondIndex]

        return SMRotation(alignX: firstAxis, alignZ: secondAxis)
    }
}
