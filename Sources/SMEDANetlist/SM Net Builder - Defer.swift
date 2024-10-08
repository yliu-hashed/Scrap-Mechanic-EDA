//
//  SM Net Builder - Defer.swift
//  Scrap Mechanic EDA
//

extension SMNetBuilder {

    public class DeferedGate {
        private var gateId: UInt64? = nil
        private var builder: SMNetBuilder
        private var creator: Creator
        public typealias Creator = ()->UInt64

        init(builder: SMNetBuilder, creator: @escaping Creator) {
            self.builder = builder
            self.creator = creator
        }

        /// Get a gate that has at least one remaining output let before it hits the limit
        public func use() -> UInt64 {
            // generate a new one if the old one can't be used anymore
            guard let gateId = gateId,
                  builder.module.gates[gateId]!.dsts.count < SMModule.gateOutputLimit else {
                let newGateId = creator()
                gateId = newGateId
                return newGateId
            }
            return gateId
        }
    }

    /// Defer the creation of a repeatedly creatable gate until it hits output limit
    public func defered(_ creator: @escaping DeferedGate.Creator) -> DeferedGate {
        return DeferedGate(builder: self, creator: creator)
    }
}
