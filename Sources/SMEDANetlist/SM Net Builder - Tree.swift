//
//  SM Net Builder - Tree.swift
//  Scrap Mechanic EDA
//

extension SMNetBuilder {

    public class TreeHandle {
        private var handles: [UInt64]
        private var builder: SMNetBuilder
        private var counter: Int = 0
        public private(set) var capacity: Int

        init(handles: [UInt64], builder: SMNetBuilder, capacity: Int) {
            self.handles = handles
            self.builder = builder
            self.capacity = capacity
        }

        public func useAndConnect(dstId: UInt64) {
            guard counter < capacity else { fatalError("Capacity violated") }
            let index = counter / SMModule.gateOutputLimit
            let srcId = handles[index]
            builder.connect(srcId, to: dstId)
            counter += 1
        }

        public func use() -> UInt64 {
            guard counter < capacity else { fatalError("Capacity violated") }
            let index = counter / SMModule.gateOutputLimit
            let srcId = handles[index]
            counter += 1
            return srcId
        }
    }

    // Build a delay-wise symmetric fanout starting from `src`.
    public func buildDriveTree(srcId: UInt64, fanout: Int, keepTiming: Bool? = nil) -> TreeHandle {
        guard let srcGate = module.gates[srcId] else {
            fatalError("Gate \(srcId) doesn't exist")
        }
        guard srcGate.dsts.isEmpty else {
            fatalError("Cannot built tree from \(srcId). It already have outputs.")
        }

        if fanout == 1 {
            return TreeHandle(handles: [srcId], builder: self, capacity: fanout)
        }

        let limit = SMModule.gateOutputLimit
        let sequential = keepTiming ?? module.sequentialNodes.contains(srcId)

        var widths: [Int] = []

        // built each layer backwards
        var currentFanout: Int = fanout
        while currentFanout != 1 {
            let prevLayerWidth = (currentFanout + limit - 1) / limit
            currentFanout = prevLayerWidth
            widths.append(prevLayerWidth)
        }
        widths.removeLast()

        // build the tree layer by layer
        var handles: [UInt64] = [srcId]
        while let width = widths.popLast() {
            var newHandles: [UInt64] = []
            for i in 0..<width {
                let index = i / limit
                let srcId = handles[index]
                let dstId = addGate(type: .logic(type: .or), keepTiming: sequential)
                connect(srcId, to: dstId)
                newHandles.append(dstId)
            }
            handles = newHandles
        }

        return TreeHandle(handles: handles, builder: self, capacity: fanout)
    }
}
