//
//  Placement - Space.swift
//  Scrap Mechanic EDA
//

import SMEDANetlist
import SMEDABlueprint

private extension PlacementConfig.Volume {
    func position(of index: Int) -> SMVector {
        let dirA = fillDirectionTertiary
        let dirB = fillDirectionSecondary
        let dirC = fillDirectionPrimary

        let sizeA = abs(size.dot(with: dirA.vector))
        let sizeB = abs(size.dot(with: dirB.vector))

        let deltaA = 1 +  index % sizeA
        let deltaB = 1 + (index / sizeA) % sizeB
        let deltaC = 1 + (index / sizeA) / sizeB

        let rectifiedA = dirA.vector * deltaA
        let rectifiedB = dirB.vector * deltaB
        let rectifiedC = dirC.vector * deltaC

        let sum = rectifiedA + rectifiedB + rectifiedC

        let rx = sum.x >= 0 ? sum.x - 1 : sum.x + size.x
        let ry = sum.y >= 0 ? sum.y - 1 : sum.y + size.y
        let rz = sum.z >= 0 ? sum.z - 1 : sum.z + size.z

        return position + SMVector(x: rx, y: ry, z: rz)
    }
}

func placementEnumerateSpace(
    _ module: borrowing SMModule,
    config: borrowing PlacementConfig,
    occupied: inout Set<SMVector>,
    portGateIds: borrowing Set<UInt64>
) throws -> Set<SMVector> {
    var space: Set<SMVector> = []

    // facility to allocate a single block of space
    var volumes = Array(config.volumes.reversed())
    var indexInVolumes: Int = 0
    func reserveSpace() throws {
        // repeat until finding a free position
        while true {
            guard let volume = volumes.last else {
                throw PlacementError.spaceNotEnouph(current: space.count)
            }

            // get position
            let position = volume.position(of: indexInVolumes)

            // check for collision
            if !occupied.contains(position) {
                space.insert(position)
                occupied.insert(position)
                return
            }

            // advance
            indexInVolumes += 1
            if indexInVolumes >= volume.size.volume {
                indexInVolumes = 0
                volumes.removeLast()
            }
        }
    }

    // go over all gates, enumerate volume
    for (gateId, gate) in module.gates {
        guard !portGateIds.contains(gateId) else { continue }
        switch gate.type {
            case .logic(_):
                try reserveSpace()
            case .timer(_):
                try reserveSpace()
                try reserveSpace()
        }
    }
    return space
}
