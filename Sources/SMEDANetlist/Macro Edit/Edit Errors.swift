//
//  Edit Errors.swift
//  Scrap Mechanic EDA
//

public enum EditError: Error, CustomStringConvertible {
    case noInputPort(port: String)
    case noOutputPort(port: String)
    case widthMismatch(argument: EditPortRoute)
    case repeatSink(port: String, index: Int)
    case shareMixed(seq: EditPort, comb: EditPort)

    public var description: String {
        switch self {
            case .noInputPort(let port):
                return "Input port \(port) does not exist"
            case .noOutputPort(let port):
                return "Output port \(port) does not exist"
            case .widthMismatch(let argument):
                return "Width mismatch in port routing \(argument)"
            case .repeatSink(let port, let index):
                return "Input port \(port)[\(index)] is driven more than once"
            case .shareMixed(let seq, let comb):
                return "Sharing between sequential port \(seq) and combinational port \(comb) is not allowed"
        }
    }
}
