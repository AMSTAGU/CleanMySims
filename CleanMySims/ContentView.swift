//
//  ContentView.swift
//  CleanMySims
//

import SwiftUI

struct ContentView: View {
    @Environment(SimulatorManager.self) private var manager
    @State private var selection: NavigationItem = .overview

    var body: some View {
        HStack(spacing: 0) {
            SidebarView(selection: $selection)
                .frame(width: Theme.Layout.sidebarWidth)

            Rectangle()
                .fill(Theme.Colors.border)
                .frame(width: 1)

            Group {
                switch selection {
                case .overview:
                    OverviewView(selection: $selection)
                case .category(let type):
                    DetailListView(category: type)
                        .id(type)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Colors.background)
        }
        .foregroundStyle(Theme.Colors.primaryText)
        .overlay {
            if manager.isCleaning {
                CleaningOverlay(done: manager.cleaningDone, total: manager.cleaningTotal)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: manager.isCleaning)
        .ignoresSafeArea()
        .frame(width: Theme.Layout.windowWidth, height: Theme.Layout.windowHeight)
        .task {
            if manager.lastScanDate == nil && !manager.isScanning {
                manager.scan()
            }
        }
    }
}

/// Blocks the window while items are being removed.
private struct CleaningOverlay: View {
    let done: Int
    let total: Int

    var body: some View {
        ZStack {
            Color.black.opacity(0.15)
                .contentShape(Rectangle())
                .onTapGesture {}

            VStack(spacing: 12) {
                Text("Cleaning…")
                    .font(Theme.Fonts.headline)
                ProgressView(value: Double(done), total: Double(max(total, 1)))
                    .frame(width: 220)
                    .tint(Theme.Colors.accent)
                Text("\(done) of \(total)")
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
            .padding(24)
            .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
        }
    }
}

#Preview {
    ContentView()
        .environment(SimulatorManager())
}
