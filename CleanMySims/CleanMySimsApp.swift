//
//  CleanMySimsApp.swift
//  CleanMySims
//

import SwiftUI

@main
struct CleanMySimsApp: App {
    @StateObject private var simulatorManager = SimulatorManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(simulatorManager)
                .frame(
                    width: Theme.Layout.windowWidth,
                    height: Theme.Layout.windowHeight
                )
                .fixedSize()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            // Remove unnecessary menu items
            CommandGroup(replacing: .newItem) { }
        }
    }
}
