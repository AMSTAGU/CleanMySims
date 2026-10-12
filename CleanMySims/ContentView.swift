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
                .fill(Color.black.opacity(0.1))
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
        .overlay(alignment: .bottom) {
            if let result = manager.lastCleanResult {
                CleanResultBanner(result: result) { manager.lastCleanResult = nil }
                    .padding(.bottom, 18)
                    .padding(.leading, Theme.Layout.sidebarWidth)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: result.isMeasuring) {
                        guard !result.isMeasuring else { return }
                        try? await Task.sleep(for: .seconds(10))
                        manager.lastCleanResult = nil
                    }
            }
        }
        .animation(.spring(duration: 0.4), value: manager.lastCleanResult)
        .alert(
            "^[\(manager.cleaningFailures.count) item](inflect: true) couldn't be removed",
            isPresented: Binding(
                get: { !manager.cleaningFailures.isEmpty },
                set: { if !$0 { manager.cleaningFailures = [] } }
            )
        ) {
            Button("OK") {}
        } message: {
            Text(failureSummary)
        }
        .ignoresSafeArea()
        .frame(width: Theme.Layout.windowWidth, height: Theme.Layout.windowHeight)
        .containerBackground(.thickMaterial, for: .window)
        .task {
            if manager.lastScanDate == nil && !manager.isScanning {
                manager.scan()
            }
        }
    }
}

extension ContentView {
    private var failureSummary: String {
        let lines = manager.cleaningFailures.prefix(5).map { "\($0.item.name): \($0.reason)" }
        let more = manager.cleaningFailures.count - lines.count
        return (lines + (more > 0 ? ["and \(more) more"] : [])).joined(separator: "\n")
    }
}

/// Space actually gained by the last clean, measured on the disk.
private struct CleanResultBanner: View {
    let result: SimulatorManager.CleanResult
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if result.isMeasuring {
                ProgressView().controlSize(.small)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.Colors.safe)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.Colors.cardStroke))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }

    private var title: String {
        let freed = result.freed.formatted(.byteCount(style: .file))
        return result.isMeasuring ? "Freeing space… \(freed) so far" : "\(freed) freed"
    }

    private var detail: String {
        let count = result.removedCount
        var parts = ["Measured on disk · \(count) item\(count == 1 ? "" : "s") removed"]
        if result.trashed > 0 {
            parts.append("\(result.trashed.formatted(.byteCount(style: .file))) in the Trash until you empty it")
        }
        return parts.joined(separator: " · ")
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
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
        }
    }
}

#Preview {
    ContentView()
        .environment(SimulatorManager())
}
