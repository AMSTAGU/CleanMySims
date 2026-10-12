//
//  CleanMySimsApp.swift
//  CleanMySims
//

import SwiftUI

@main
struct CleanMySimsApp: App {
    @State private var simulatorManager = SimulatorManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(simulatorManager)
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
                window.titleVisibility = .hidden
                // Ensure the style mask supports full size content and standard window features
                window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
                window.isMovableByWindowBackground = true
                window.isOpaque = false // Allow transparency for the rounded corners if using materials
                window.backgroundColor = .clear // Important for containerBackground to show through
                window.hasShadow = true
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
