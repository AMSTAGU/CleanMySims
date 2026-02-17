//
//  CleanMySimsApp.swift
//  CleanMySims
//
//  Created by Amaury Gau on 23/12/2025.
//

import SwiftUI

@main
struct CleanMySimsApp: App {
    @StateObject private var simulatorManager = SimulatorManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(simulatorManager)
        }
    }
}
