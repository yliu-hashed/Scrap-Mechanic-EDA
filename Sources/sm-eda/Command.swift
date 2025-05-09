//
//  Command.swift
//  Scrap Mechanic EDA
//

import Foundation
import ArgumentParser

private let discussion = "This is the Scrap Mechanic EDA command line toolset."

@main struct SMEDA: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "sm-eda",
        discussion: discussion,
        subcommands: [
            YS2SMCMD.self,
            PlaceCMD.self,
            AutoPlanCMD.self,
            BRAMCMD.self,
            EditCMD.self,
            SimCMD.self,
            ShowCMD.self,
        ]
    )
}
