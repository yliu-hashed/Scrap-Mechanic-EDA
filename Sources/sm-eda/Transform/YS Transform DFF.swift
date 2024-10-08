//
//  YS Transform DFF.swift
//  Scrap Mechanic EDA
//

import SMEDANetlist

func checkDFF(name: String, cell: borrowing YSCell, updating outputLUTs: inout [UInt64: TransformOutputStore]) throws {
    guard (3...4).contains(cell.conns.count),
          cell.conns.allSatisfy({ $0.value.count == 1 }),
          let outputBits = cell.conns.first(where: { $0.key == "Q" })?.value,
          outputBits.count == 1,
          case .shared(let id) = outputBits[0] else {

        throw TransformError.malformedCellPorts(cellName: name)
    }
    guard !outputLUTs.keys.contains(id) else {
        throw TransformError.duplicateOutput(
            connId: id, cellName1: name,
            cellName2: outputLUTs[id]!.nodeName
        )
    }
    let outputStore = TransformOutputStore(nodeName: name, connName: "Q", bitIndex: 0)
    outputLUTs.updateValue(outputStore, forKey: id)
}

/// Build a edge triggered d-type flip flop. This design is edge triggered, and using 6 gates and 9
/// internal connections.
func emitDFF(builder: SMNetBuilder) -> DFFTarget {
    /*-----------------------------------------------------------*/
    /*               Edge Triggered D-Type Flip Flop             */
    /*----- Posedge Vairation -----X----------- NAMES -----------*/
    /* [C]     [D]                 | [C]     [D]                 */
    /*  |\      |      .--<-.      |  |\      |      .--<-.      */
    /*  | \     |      |    |      |  | \     |      |    |      */
    /*  | nor  xor-<--xor---|--[Q] |  | cInv diff-<-xlp0--|--[Q] */
    /*  | /     |    / |    |      |  | /     |    / |    |      */
    /*  and-----'   +-xor   |      | filt-----'   +-xlp1  |      */
    /*   |         /   |    |      |   |         /   |    |      */
    /*   '----->--+---xor   |      |   '----->--+---xlp2  |      */
    /*                 |    |      |                 |    |      */
    /*                 '->--'      |                 '->--'      */
    /*-----------------------------X-----------------------------*/
    /* cInv: invert of the clock, use to detect edge             */
    /* filt: detect edge and emit single tick for change         */
    /* diff: detect difference of the D and current ff state     */
    /* xlp0: storage loop, connects to previous and change       */
    /* xlp1: same                                                */
    /* xlp2: same                                                */
    /*-----------------------------------------------------------*/

    let target = DFFTarget(
        cInv: builder.addLogic(type: .nor, keepTiming: true),
        filt: builder.addLogic(type: .and, keepTiming: true),
        diff: builder.addLogic(type: .xor, keepTiming: false),

        xlp0: builder.addLogic(type: .xor, keepTiming: true),
        xlp1: builder.addLogic(type: .xor, keepTiming: true),
        xlp2: builder.addLogic(type: .xor, keepTiming: true)
    )

    // connect primary store loop
    builder.connect(target.xlp0, to: target.xlp1)
    builder.connect(target.xlp1, to: target.xlp2)
    builder.connect(target.xlp2, to: target.xlp0)
    // connect edge detection
    builder.connect(target.cInv, to: target.filt)
    // connect change detection
    builder.connect(target.xlp0, to: target.diff)
    // connect change handel
    builder.connect(target.diff, to: target.filt)
    // connect change circuit
    builder.connect(target.filt, to: target.xlp0)
    builder.connect(target.filt, to: target.xlp1)
    builder.connect(target.filt, to: target.xlp2)

    return target
}

struct DFFTarget: CellLowerTarget {
    var cInv: UInt64
    var filt: UInt64
    var diff: UInt64
    var xlp0: UInt64
    var xlp1: UInt64
    var xlp2: UInt64

    func gateFor(port: String, bit: Int) -> [UInt64] {
        switch port {
            case "D":
                return [diff]
            case "C":
                return [cInv, filt]
            case "Q":
                return [xlp0]
            case "E":
                return [filt]
            default:
                fatalError()
        }
    }
}

func checkDFFWithAsyncReset(name: String, cell: borrowing YSCell, updating outputLUTs: inout [UInt64: TransformOutputStore]) throws {
    guard (4...5).contains(cell.conns.count),
          cell.conns.allSatisfy({ $0.value.count == 1 }),
          let outputBits = cell.conns.first(where: { $0.key == "Q" })?.value,
          outputBits.count == 1,
          case .shared(let id) = outputBits[0] else {

        throw TransformError.malformedCellPorts(cellName: name)
    }
    guard !outputLUTs.keys.contains(id) else {
        throw TransformError.duplicateOutput(
            connId: id, cellName1: name,
            cellName2: outputLUTs[id]!.nodeName
        )
    }
    let outputStore = TransformOutputStore(nodeName: name, connName: "Q", bitIndex: 0)
    outputLUTs.updateValue(outputStore, forKey: id)
}

func emitDFFWithAsyncReset(builder: SMNetBuilder) -> DFFWithAsyncResetTarget {
    /*---------------------------------------------------------------*/
    /*        Edge Triggered D-Type Flip Flop With Async Reset       */
    /*--------------- NAMES ---------------X---------- GATES --------*/
    /*  [C]     [D]         [Q]    [R]     |          [Q]    [R]     */
    /*   |\      |          /       |\     |          /       |\     */
    /*   | \     |      .----<--.   | \    |      .----<--.   | \    */
    /*   |  \    |      | /     |   |  \   |      | /     |   |  \   */
    /*   |cInv diff-<-xlp0--->--|-. | rinv | ...xlp0--->--|-. | nor  */
    /*   | /     |    / | \     |  \|/     |      | \     |  \|/     */
    /*  filt-----'   +xlp1-+    |  rFlt    | ...xlp1-+    |  and     */
    /*    |         /   |   \   |   |      |      |   \   |   |      */
    /*    '----->--+--xlp2---+--|<-rbuf    | ...xlp1---+--|<--or     */
    /*                  |       |          |      |       |          */
    /*                  '--->---'          |      '--->---'          */
    /*-------------------------------------X-------------------------*/


    let target = DFFWithAsyncResetTarget(
        rInv: builder.addLogic(type: .nor, keepTiming: true),

        rFlt: builder.addLogic(type: .and, keepTiming: true),
        sbuf: builder.addLogic(type: .or,  keepTiming: true),

        cInv: builder.addLogic(type: .nor, keepTiming: true),

        filt: builder.addLogic(type: .and, keepTiming: true),
        diff: builder.addLogic(type: .xor, keepTiming: false),

        xlp0: builder.addLogic(type: .xor, keepTiming: true),
        xlp1: builder.addLogic(type: .xor, keepTiming: true),
        xlp2: builder.addLogic(type: .xor, keepTiming: true)
    )

    // connect primary store loop
    builder.connect(target.xlp0, to: target.xlp1)
    builder.connect(target.xlp1, to: target.xlp2)
    builder.connect(target.xlp2, to: target.xlp0)

    // connect edge detection
    builder.connect(target.cInv, to: target.filt)
    // connect change detection
    builder.connect(target.xlp0, to: target.diff)
    // connect change handel
    builder.connect(target.diff, to: target.filt)
    // connect change circuit
    builder.connect(target.filt, to: target.xlp0)
    builder.connect(target.filt, to: target.xlp1)
    builder.connect(target.filt, to: target.xlp2)

    // connect reset edge detection
    builder.connect(target.rInv, to: target.rFlt)
    // connect reset handel
    builder.connect(target.xlp0, to: target.rFlt)

    builder.connect(target.rFlt, to: target.sbuf)
    // connect reset circuit
    builder.connect(target.sbuf, to: target.xlp0)
    builder.connect(target.sbuf, to: target.xlp1)
    builder.connect(target.sbuf, to: target.xlp2)

    return target
}

struct DFFWithAsyncResetTarget: CellLowerTarget {
    var rInv: UInt64
    var rFlt: UInt64
    var sbuf: UInt64

    var cInv: UInt64
    var filt: UInt64
    var diff: UInt64
    var xlp0: UInt64
    var xlp1: UInt64
    var xlp2: UInt64

    func gateFor(port: String, bit: Int) -> [UInt64] {
        switch port {
            case "D":
                return [diff]
            case "C":
                return [cInv, filt]
            case "Q":
                return [xlp0]
            case "R":
                return [rInv, rFlt]
            case "E":
                return [rFlt]
            default:
                fatalError()
        }
    }
}
