//
//  ContentView.swift
//  CleanMySims
//
//  Created by Amaury Gau on 23/12/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var selection: NavigationItem? = .dashboard
    @EnvironmentObject var simulatorManager: SimulatorManager
    
    var body: some View {
        ZStack {
            Theme.Colors.background
                .ignoresSafeArea()
            
            NavigationSplitView {
                SidebarView(selection: $selection)
            } detail: {
                ZStack {
                    // Detail background (can be slightly lighter or just transparent to show global gradient)
                    Color.clear
                    
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
            }
            .background(.clear) // Important for the gradient to show through custom split view styles if possible
        }
        .frame(minWidth: 900, minHeight: 600)
    }
}

#Preview {
    ContentView()
        .environmentObject(SimulatorManager())
}
