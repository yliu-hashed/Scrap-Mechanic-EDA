//
//  Placement Engine.swift
//  Scrap Mechanic EDA
//

import SMEDANetlist
import SMEDABlueprint
import SMEDAResult

/*------------------------ Gate Net ------------------------*/
/*                                                          */
/*           *------------------------------*               */
/*          /                              /|               */
/*         /                              / |               */
/*        /                              /  |               */
/*       /                              /   |-*             */
/*      *------------------------------*    |/|             */
/*      |                              |    * |             */
/*      |                              |    | *             */
/*      |                       *------*    |/              */
/*      |                      /      /|    *               */
/*      |                     *------* |   /    (Z)(X)      */
/*      *---------------------|      | *  /       |/        */
/*     /                      |      |/|O/   (Y)--*         */
/*    *-----------------------*------* |/                   */
/*    |                              | *                    */
/*    |                              |/                     */
/*    *------------------------------*                      */
/*                                                          */
/*----------------------------------------------------------*/

class SimplePlacementEngine: PlacementEngine {
    private var inputs: [Int] = []
    private var outputs: [Int] = []
    private var logicCount: Int = 0
    private var timerCount: Int = 0

    private var widthWrapping: Int?
    private var depth: Int?
    private var facadeMode: Bool

    private var layout: Layout? = nil

    private var portLocation: PortLocation
    private var packPort: Bool

    enum PlacementError: Error, CustomStringConvertible {
        case tooFewInternalGates(count: Int, minCount: Int, depth: Int)

        var description: String {
            switch self {
                case .tooFewInternalGates(let count, let minCount, let depth):
                    return "\(count) internal gates is too few for placement with depth \(depth). Minimum is \(minCount)"
            }
        }
    }

    private struct Layout {
        var inputMap: [Int: PortPosition]
        var outputMap: [Int: PortPosition]
        var inputHeightTotal: Int
        var outputHeightTotal: Int
        var width: Int
        var height: Int
        var depth: Int
        var timerLocations: [TimerLocation]
        var timers: Int { timerLocations.count }
        var gateExclusionLocations: Set<SMVector>

        struct TimerLocation {
            var location: SMVector
            var pointing: SMDirection
        }
    }

    enum PortLocation: Int, CaseIterable {
        case bothSide
        case front

        var extraWidth: Int {
            switch self {
                case .bothSide: return 2
                case .front:    return 1
            }
        }
    }

    required init(widthWrapping: Int?, depth: Int?, facadeMode: Bool = false, portLocation: PortLocation, packPort: Bool) {
        self.widthWrapping = widthWrapping
        self.depth = depth
        self.facadeMode = facadeMode
        self.portLocation = portLocation
        self.packPort = packPort
    }

    func layout(inputs: [Int], outputs: [Int], logicCount: Int, timerCount: Int) throws {
        if let depth = depth {
            guard logicCount >= depth else {
                throw PlacementError.tooFewInternalGates(count: logicCount, minCount: depth, depth: depth)
            }
        }

        self.inputs = inputs
        self.outputs = outputs
        self.logicCount = logicCount
        self.timerCount = timerCount

        // calculate width wrapping
        let width: Int
        if let widthWrapping = widthWrapping {
            width = widthWrapping
        } else {
            let maxPortWidth = max(inputs.max() ?? 1, outputs.max() ?? 1)
            let maxSensableWidth = 16
            width = min(maxPortWidth, maxSensableWidth)
        }

        // place inputs
        let (inputMap,  inputHeight)  = layoutPorts(ports: inputs, widthWrapping: width, packed: packPort)
        let (outputMap, outputHeight) = layoutPorts(ports: outputs, widthWrapping: width, packed: packPort)

        // calcualte dimensions
        let placementDepth: Int
        if let depth = depth {
            placementDepth = depth
        } else {
            let counts = logicCount + timerCount * 2
            let portHeight = portLocation == .bothSide ? max(inputHeight, outputHeight) : inputHeight + outputHeight
            let planeSize = max(portHeight, 1) * width
            placementDepth = min(max(counts / planeSize, 1), 32)
        }
        let surface = width * placementDepth
        let height = max((logicCount + timerCount + surface - 1) / surface, 1)

        // place timers at the minimum volume acceptable
        var timerLocations: [Layout.TimerLocation] = []
        timerLocations.reserveCapacity(timerCount)
        var gateExclusionLocations: Set<SMVector> = []
        gateExclusionLocations.reserveCapacity(timerCount * 2)

        for _ in 0..<timerCount {
            var location = SMVector.zero
            var direction = SMDirection.negX
            while true {
                // select a random location
                location = SMVector(x: Int.random(in: 0..<placementDepth),
                                    y: Int.random(in: 0..<width),
                                    z: Int.random(in: 0..<height))
                if gateExclusionLocations.contains(location) { continue }
                // select a random direction
                direction = SMDirection.random()
                let secLocation = location + direction.vector
                guard secLocation.x >= 0, secLocation.x < placementDepth,
                      secLocation.y >= 0, secLocation.y < width,
                      secLocation.z >= 0, secLocation.z < height,
                      !gateExclusionLocations.contains(secLocation)
                else { continue }
                // found a valid one
                break
            }

            let loc = Layout.TimerLocation(location: location,
                                           pointing: direction)
            timerLocations.append(loc)
            gateExclusionLocations.update(with: location)
            gateExclusionLocations.update(with: location + direction.vector)
        }
        // set layout
        layout = Layout(inputMap: inputMap,
                        outputMap: outputMap,
                        inputHeightTotal: inputHeight,
                        outputHeightTotal: outputHeight,
                        width: width,
                        height: height,
                        depth: placementDepth,
                        timerLocations: timerLocations,
                        gateExclusionLocations: gateExclusionLocations)
    }

    private struct PortPosition: Equatable, Comparable {
        var height: Int
        var offset: Int
        var amount: Int

        static func < (lhs: PortPosition, rhs: PortPosition) -> Bool {
            if lhs.height != rhs.height {
                return lhs.height < rhs.height
            } else {
                return lhs.offset < rhs.offset
            }
        }
    }

    private func layoutPorts(ports: borrowing [Int], widthWrapping: Int, packed: Bool) -> (mapping: [Int: PortPosition], height: Int) {
        if packed {
            return layoutPortsPacked(ports: ports, widthWrapping: widthWrapping)
        } else {
            return layoutPortsOrdered(ports: ports, widthWrapping: widthWrapping)
        }
    }

    private func layoutPortsPacked(ports: borrowing [Int], widthWrapping: Int) -> (mapping: [Int: PortPosition], height: Int) {
        var layers: [Int] = []
        var locations: [Int: PortPosition] = [:]
        let portsRanked = ports.enumerated().sorted { $0.element > $1.element }
        for (index, portSize) in portsRanked {
            // if can fit, add
            let fitLayer = layers.firstIndex { widthWrapping - $0 >= portSize }
            if let fitLayer = fitLayer {
                locations[index] = PortPosition(height: fitLayer, offset: layers[fitLayer], amount: portSize)
                layers[fitLayer] += portSize
                continue
            }
            // if cannot fit, add a new layer
            let layersRequired = (portSize + widthWrapping - 1) / widthWrapping
            locations[index] = PortPosition(height: layers.count, offset: 0, amount: portSize)
            for layer in 0..<layersRequired {
                let bitsInLayer = min(portSize - layer * widthWrapping, widthWrapping)
                layers.append(bitsInLayer)
            }
        }
        return (mapping: locations, height: layers.count)
    }

    private func layoutPortsOrdered(ports: borrowing [Int], widthWrapping: Int) -> (mapping: [Int: PortPosition], height: Int) {
        var layers: [Int] = []
        var locations: [Int: PortPosition] = [:]
        for (index, portSize) in ports.enumerated() {
            let lastLayer: Int
            if let last = layers.last {
                lastLayer = last
            } else {
                lastLayer = widthWrapping
            }
            // if can fit, add
            if lastLayer + portSize <= widthWrapping {
                locations[index] = PortPosition(height: layers.count - 1, offset: lastLayer, amount: portSize)
                layers[layers.count - 1] += portSize
                continue
            }
            // if cannot fit, add a new layer
            let layersRequired = (portSize + widthWrapping - 1) / widthWrapping
            locations[index] = PortPosition(height: layers.count, offset: 0, amount: portSize)
            for layer in 0..<layersRequired {
                let bitsInLayer = min(portSize - layer * widthWrapping, widthWrapping)
                layers.append(bitsInLayer)
            }
        }
        return (mapping: locations, height: layers.count)
    }

    private func placePortPosition(heightMap: [Int: PortPosition], index: Int,
                                   bit: Int, x: Int) -> SMVector {
        guard let layout = layout else { fatalError() }

        let port = heightMap[index]!
        let zPosBase = port.height
        let zPos = (bit + port.offset) / layout.width + zPosBase
        let yPos = (bit + port.offset) % layout.width
        return SMVector(x: x, y: yPos, z: zPos)
    }

    func placeInputs(index: Int, bit: Int) -> PlacementInfo {
        guard let layout = layout else { fatalError() }
        let pos = placePortPosition(heightMap: layout.inputMap,
                                    index: index, bit: bit, x: -1)
        return PlacementInfo(pos: pos, rot: .device(facing: .negX, pointing: .posY))
    }

    func placeDeviceForInput(index: Int, bit: Int) -> PlacementInfo {
        let gatePos = placeInputs(index: index, bit: bit).pos
        return PlacementInfo(pos: gatePos + .init(x: -1),
                             rot: .device(facing: .negX, pointing: .posY))
    }

    func placeOutputs(index: Int, bit: Int) -> PlacementInfo {
        guard let layout = layout else { fatalError() }
        let pos: SMVector
        let rot: SMRotation
        switch portLocation {
            case .bothSide:
                pos = placePortPosition(heightMap: layout.outputMap,
                                        index: index, bit: bit, x: layout.depth)
                rot = .device(facing: .posX, pointing: .posY)
            case .front:
                pos = placePortPosition(heightMap: layout.outputMap,
                                        index: index, bit: bit, x: -1) + SMVector(z: layout.inputHeightTotal)
                rot = .device(facing: .negX, pointing: .posY)
        }
        return PlacementInfo(pos: pos, rot: rot)
    }

    private var gateIndex: Int = 0
    func placeLogic() -> PlacementInfo {
        guard let layout = layout else { fatalError() }

        var pos: SMVector = .one
        while true {
            let xPos =  gateIndex % layout.depth
            let yPos = (gateIndex / layout.depth) % layout.width
            let zPos = (gateIndex / layout.depth) / layout.width
            pos = SMVector(x: xPos, y: yPos, z: zPos)
            if layout.gateExclusionLocations.contains(pos) {
                gateIndex += 1
            } else { break }
        }

        let rot: SMRotation
        if facadeMode {
            if (pos.x > 0 || pos.x < layout.depth  - 1 ||
                pos.y > 0 || pos.y < layout.width  - 1 ||
                pos.z > 0 || pos.z < layout.height - 1) {

                rot = .zero
            } else {
                rot = SMRotation.random()
            }
        } else {
            let faceBottom = SMRotation.device(facing: .negZ, pointing: .posX)
            let faceTop    = SMRotation.device(facing: .posZ, pointing: .posX)
            rot = (pos.z == 0) ? faceTop : faceBottom
        }

        gateIndex += 1
        return PlacementInfo(pos: pos, rot: rot)
    }

    private var timerIndex: Int = 0
    func placeTimer() -> PlacementInfo {
        guard let layout = layout else { fatalError() }
        let location = layout.timerLocations[timerIndex]
        timerIndex += 1
        return PlacementInfo(pos: location.location, rot: .timer(pointing: location.pointing))
    }

    // MARK: Printing
    func printPlaced(inputNames: [String], outputNames: [String]) {
        guard let layout = layout,
              inputNames.count == layout.inputMap.count,
              outputNames.count == layout.outputMap.count
        else { fatalError() }

        print("Placement Info:")
        print("   Depth: \(layout.depth) + \(portLocation.extraWidth)(for ports)")
        print("   Width: \(layout.width)")
        print("   Height: \(layout.height)")
        switch portLocation {
            case .bothSide:
                print("      In Height: \(layout.inputHeightTotal)")
                print("     Out Height: \(layout.outputHeightTotal)")
            case .front:
                let portHeight = layout.inputHeightTotal + layout.outputHeightTotal
                print("   Ports Height: \(portHeight)")
        }

        print("   Inputs:")
        printPortGroup(map: layout.inputMap, names: inputNames, width: layout.width, height: layout.inputHeightTotal)

        print("   Outputs:")
        printPortGroup(map: layout.outputMap, names: outputNames, width: layout.width, height: layout.outputHeightTotal)
        print()
    }

    private func printPortGroup(map: borrowing [Int: PortPosition], names: borrowing [String], width: Int, height: Int) {
        let sortedMap = map.sorted { $0.value < $1.value }
        for (i, _) in sortedMap.reversed() {
            let name = names[i]
            print("    \(getAlphabet(index: i)): \(name)")
        }
        let matrix = generateIndexMatrix(using: map, width: width, height: height)
        printIndexMatrix(matrix, width: width, height: height)
    }

    private func generateIndexMatrix(using map: borrowing [Int: PortPosition], width: Int, height: Int) -> [Int] {
        var bits: [Int] = .init(repeating: -1, count: width * height)
        for (index, port) in map.lazy {
            for bit in 0..<port.amount {
                let vPos = (bit + port.offset) / width + port.height
                let hPos = (bit + port.offset) % width
                bits[vPos * width + hPos] = index
            }
        }
        return bits
    }

    private func printIndexMatrix(_ matrix: borrowing [Int], width: Int, height: Int) {
        var last: Int? = nil
        print("┌" + String(repeating: "─", count: width * 2 + 1) + "┐")
        for i in (0..<height).reversed() {
            print("│ ", terminator: "")
            for j in (0..<width).reversed() {
                let k = matrix[i * width + j]
                if let last = last {
                    let continued = last == k && last != -1
                    print(continued ? "-" : " ", terminator: "")
                }
                if k != -1 {
                    print(getAlphabet(index: k), terminator: "")
                } else {
                    print("*", terminator: "")
                }
                last = k
            }
            last = nil
            print(" │")
        }
        print("└" + String(repeating: "─", count: width * 2 + 1) + "┘")
    }

    // MARK: Report
    func reportPlaced(inputNames: [String], outputNames: [String]) -> PlacementReport {
        guard let layout = layout,
              inputNames.count == layout.inputMap.count,
              outputNames.count == layout.outputMap.count
        else { fatalError() }

        var report = PlacementReport()
        report.width = layout.width
        report.depth = layout.depth
        report.height = layout.height

        let inputs  = reportPortGroup(
            map: layout.inputMap,
            names: inputNames,
            width: layout.width,
            height: layout.height
        )

        let outputs = reportPortGroup(
            map: layout.outputMap,
            names: outputNames,
            width: layout.width,
            height: layout.height
        )

        report.surfaces = [
            "inputs": inputs,
            "outputs": outputs
        ]

        return report
    }

    private func reportPortGroup(
        map: borrowing [Int: PortPosition],
        names: borrowing [String],
        width: Int,
        height: Int
    ) -> PlacementReport.PortSurface {
        var group: [[PlacementReport.PortSegment]] = [[]]

        let sortedMap = map.sorted { $0.value < $1.value }

        var hpos: Int = 0
        var vpos: Int = 0
        var i: Int = 0
        var left: Int = 0
        while i < sortedMap.count {
            let (currNameIndex, currPos) = sortedMap[i]
            if vpos == currPos.height && hpos == currPos.offset {
                assert(left == 0)
                left += currPos.amount
            }
            if left > 0 {
                let consume = min(width - hpos, left)
                let item = PlacementReport.PortSegment(
                    name: names[currNameIndex],
                    lsb: currPos.amount - left,
                    msb: currPos.amount - left + consume - 1,
                    offset: hpos
                )
                group[group.count - 1].append(item)
                left -= consume
                hpos += consume
                if left == 0 { i += 1 }
            } else {
                hpos += 1
            }
            if hpos >= width {
                hpos = 0
                vpos += 1
                group.append([])
            }
        }

        if group.last?.isEmpty ?? false {
            group.removeLast()
        }
        return group
    }
}

private let alphabet = "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
private func getAlphabet(index: Int) -> Character {
    let stringIndex = alphabet.index(alphabet.startIndex, offsetBy: index % alphabet.count)
    return alphabet[stringIndex]
}
