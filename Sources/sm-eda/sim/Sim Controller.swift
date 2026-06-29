//
//  Sim Controller.swift
//  Scrap Mechanic EDA
//

import SMEDANetlist
import Foundation

class Controller {
    let model: SimulationModel
    let isRepl: Bool

    init(model: SimulationModel, isRepl: Bool) {
        self.model = model
        self.isRepl = isRepl
    }

    func run(command: SimStep, printlevel: PrintLevel) {
        switch (command) {
        case .quit:
            return
        case .tick(let amount):
            guard amount > 0 else {
                return
            }
            if !model.wrapToStable(ticks: Int(amount)) {
                print(for: .warning, "Cannot reach stability in \(amount) ticks.")
            }
        case .wrap:
            guard model.isInstable || model.willChange else {
                if isRepl {
                    print("Already stable!")
                }
                return
            }
            if !model.wrapToStable(time: 5) {
                print(for: .warning, "Cannot reach stability in 5s!")
            }
        case .reset:
            model.resetAll()
        case .input(let value, let port):
            if !model.setInput(constant: value, port: port) {
                return
            }
        case .assert(let constant, let port):
            guard let value = model.getOutput(port: port) else { return }
            if value != constant {
                let text = "Assertion '\(port)' == '\(constant)' failed. Got '\(value)' instead."
                print(for: .error, text)
                if !isRepl {
                    fatalError("Assertion failed.")
                }
            }
        case .record:
            model.beginRecording()
            if isRepl {
                print("Recording started.")
            }
            return
        case .stopRecord:
            model.stopRecording()
            if isRepl {
                print("Recording stopped.")
            }
            return
        case .saveRecord(let path):
            let url = URL(filePath: path, directoryHint: .notDirectory)
            let string = model.generateRecordedVCD()
            let data = string.data(using: .utf8)!
            do {
                try data.write(to: url)
            } catch {
                print(for: .error, "Cannot save with error: \(error.localizedDescription)")
            }
            return
        case .help:
            if isRepl {
                print(subCommandHelp)
            } else {
                print(for: .warning, "Command 'help' does nothing in scripting mode.")
            }
            return
        }
        if isRepl { model.printState() }
    }
}
