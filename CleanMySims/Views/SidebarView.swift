//
//  SidebarView.swift
//  CleanMySims
//
//  Created by Amaury Gau on 23/12/2025.
//

import SwiftUI

enum NavigationItem: Hashable, Identifiable, CaseIterable {
    case dashboard
    case cache
    case devices
    case runtimes
    case builds
    case deviceSupport
    
    var id: Self { self }
    
    var label: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .cache: return "Caches & Data"
        case .devices: return "Simulators"
        case .runtimes: return "Runtimes"
        case .builds: return "Builds (Derived Data)"
        case .deviceSupport: return "iOS Device Support"
        }
    }
    
    var icon: String {
        switch self {
        case .dashboard: return "gauge.medium"
        case .cache: return "trash"
        case .devices: return "iphone"
        case .runtimes: return "gearshape.2"
        case .builds: return "hammer.circle"
        case .deviceSupport: return "iphone.circle"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: NavigationItem?
    
    var body: some View {
        List(selection: $selection) {
            Section("General") {
                NavigationLink(value: NavigationItem.dashboard) {
                    Label(NavigationItem.dashboard.label, systemImage: NavigationItem.dashboard.icon)
                        .font(Theme.Fonts.body)
                        .padding(.vertical, 4)
                }
            }
            .listRowBackground(Color.clear)
            
            Section("Details") {
                ForEach([NavigationItem.cache, NavigationItem.devices, NavigationItem.runtimes, NavigationItem.builds, NavigationItem.deviceSupport]) { item in
                    NavigationLink(value: item) {
                        Label(item.label, systemImage: item.icon)
                            .font(Theme.Fonts.body)
                            .padding(.vertical, 4)
                    }
                }
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden) // Makes the list background transparent
        .background(Material.thin) // Adds a subtle blur behind the sidebar
        .frame(minWidth: 220)
    }
}
