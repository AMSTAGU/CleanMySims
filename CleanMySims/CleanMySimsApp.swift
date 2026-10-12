//
//  CleanMySimsApp.swift
//  CleanMySims
//

import SwiftUI

@main
struct CleanMySimsApp: App {
    @State private var manager = SimulatorManager()
    @AppStorage("appearance") private var appearance: AppearanceMode = .system

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(manager)
                .onAppear { NSApp.appearance = appearance.nsAppearance }
                .onChange(of: appearance) { _, mode in
                    NSApp.appearance = mode.nsAppearance
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .windowBackgroundDragBehavior(.enabled)
        .defaultSize(width: Theme.Layout.windowWidth, height: Theme.Layout.windowHeight)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Rescan") { manager.scan() }
                    .keyboardShortcut("r")
                    .disabled(manager.isScanning || manager.isCleaning)
            }
            CommandGroup(after: .toolbar) {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            }
        }
    }
}
