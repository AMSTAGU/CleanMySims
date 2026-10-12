//
//  ContentView.swift
//  CleanMySims
//

import SwiftUI

struct ContentView: View {
    @State private var selection: NavigationItem? = .dashboard
    @Environment(SimulatorManager.self) private var simulatorManager

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                SidebarView(selection: $selection)
                    .frame(width: Theme.Layout.sidebarWidth)
                    .frame(maxHeight: .infinity)

                Rectangle()
                    .fill(Color.black.opacity(0.1)) // Lighter grey as requested
                    .frame(width: 1)
                    .ignoresSafeArea()


                Group {
                    switch selection {
                    case .dashboard, nil:
                        DashboardView()
                    case .cache:
                        DetailListView(category: .cache)
                    case .devices:
                        DetailListView(category: .virtualDevice)
                    case .runtimes:
                        DetailListView(category: .runtimes)
                    case .builds:
                        DetailListView(category: .builds)
                    case .deviceSupport:
                        DetailListView(category: .deviceSupport)
                    case .testClones:
                        DetailListView(category: .testClones)
                    case .previews:
                        DetailListView(category: .previews)
                    case .archives:
                        DetailListView(category: .archives)
                    case .androidEmulators:
                        DetailListView(category: .androidEmulator)
                    case .gradleCache:
                        DetailListView(category: .gradleCache)
                    case .androidStudioCache:
                        DetailListView(category: .androidStudioCache)
                    case .androidSdk:
                        DetailListView(category: .androidSdk)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.clear)
            .containerBackground(.thickMaterial, for: .window)
            
            // Global Loading Overlay with interaction blocker
            if simulatorManager.isScanning {
                Color.black.opacity(0.01) // Almost invisible, just enough to block clicks? 
                // Actually user said "assombrit trop", so let's make it very subtle or just clear with contentShape
                    .ignoresSafeArea()
                    .contentShape(Rectangle()) // Ensure it catches taps
                    .onTapGesture { } // Block taps
                
                LoadingOverlay(title: "Scanning...", isIndeterminate: true)
            }
            
            if simulatorManager.isCleaning {
                Color.black.opacity(0.01) // Subtle background to block taps
                    .ignoresSafeArea()
                    .contentShape(Rectangle()) // Ensure it catches taps
                    .onTapGesture { } // Block taps
                
                LoadingOverlay(title: "Cleaning...", isIndeterminate: true)
            }

        }
        .frame(width: Theme.Layout.windowWidth, height: Theme.Layout.windowHeight)
    }
}

#Preview {
    ContentView()
        .environment(SimulatorManager())
}
