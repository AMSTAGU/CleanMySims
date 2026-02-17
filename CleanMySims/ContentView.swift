//
//  ContentView.swift
//  CleanMySims
//

import SwiftUI

struct ContentView: View {
    @State private var selection: NavigationItem? = .dashboard
    @EnvironmentObject var simulatorManager: SimulatorManager

    var body: some View {
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
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(VisualEffectBlur(material: .sidebar, blendingMode: .behindWindow).ignoresSafeArea())
        .frame(width: Theme.Layout.windowWidth, height: Theme.Layout.windowHeight)
    }
}

#Preview {
    ContentView()
        .environmentObject(SimulatorManager())
}
