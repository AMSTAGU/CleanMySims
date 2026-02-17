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
                .background(WindowAccessor())
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: Theme.Layout.windowWidth, height: Theme.Layout.windowHeight)
        .commands {
            // Remove unnecessary menu items
            CommandGroup(replacing: .newItem) { }
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.titlebarAppearsTransparent = true
                window.styleMask.insert(.fullSizeContentView)
                // Revert to standard window behavior
                // window.isMovableByWindowBackground = true // Optional, usually good for hidden title bar
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
