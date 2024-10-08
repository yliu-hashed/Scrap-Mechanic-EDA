//
//  Sim Controller.swift
//  Scrap Mechanic EDA
//

class Controller {
    let model: SimulationModel
    let isRepl: Bool

    init(model: SimulationModel, isRepl: Bool) {
        self.model = model
        self.isRepl = isRepl
    }

    func run(command: SimStep) {
        switch (command) {
            case .quit:
                return
            case .tick(let amount):
                guard amount > 0 else {
                    if isRepl { print("Does Nothing") }
                    return
                }
                model.wrapToStable(limit: Int(amount))
            case .wrap:
                guard model.isInstable || model.willChange else {
                    if isRepl { print("Already Stable") }
                    return
                }
                model.wrapToStable()
            case .reset:
                model.resetAll()
            case .input(let value, let port):
                if !model.setInput(constant: value, port: port) {
                    return
                }
            case .assert(let constant, let port):
                guard let value = model.getOutput(port: port) else { return }
                if value != constant {
                    fatalError("Assertion Failed: \(port) == \(value) != \(constant)")
                }
            case .record:
                model.beginRecording()
                if isRepl { print("Recording Started") }
                return
            case .stopRecord:
                model.stopRecording()
                if isRepl { print("Recording Stopped") }
                return
            case .saveRecord(let url):
                let string = vcdGen(module: model.module, duration: model.recordingTime, history: model.history)
                let data = string.data(using: .utf8)!
                do {
                    try data.write(to: url)
                } catch {
                    print("Error: Cannot save file: \(error.localizedDescription)")
                }
                return
            case .help:
                if isRepl {
                    print(subCommandHelp)
                } else {
                    print("Warning: Command `help` does nothing in scripting mode")
                }
                return
        }
        if isRepl { model.printState() }
    }
}
