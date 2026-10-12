//
//  OverviewView.swift
//  CleanMySims
//

import SwiftUI

/// Home screen: total, treemap of every category, and the "clean safe items" shortcut.
/// While scanning it shows live progress and the treemap fills in as sizes arrive.
struct OverviewView: View {
    @Binding var selection: NavigationItem
    @Environment(SimulatorManager.self) private var manager
    @State private var confirmSafeClean = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            totals
            if manager.isScanning {
                scanProgress
            }
            treemap
            if !manager.isScanning && manager.safeSize > 0 {
                safeCleanCard
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 18)
        .padding(.bottom, 22)
        .alert("Clean safe items?", isPresented: $confirmSafeClean) {
            Button("Clean", role: .destructive) {
                manager.clean(manager.safeItems)
            }
        } message: {
            Text("\(manager.safeItems.count) items, \(manager.safeSize.formatted(.byteCount(style: .file))). Deleted permanently (simulators and system caches through simctl). Xcode and Gradle recreate them when needed.")
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 12) {
            Text(manager.isScanning ? "Scanning…" : "Overview")
                .font(Theme.Fonts.headline)
            status
                .font(.system(size: 12))
                .foregroundStyle(Theme.Colors.secondaryText)
            Spacer()
            if manager.isScanning {
                IconPillButton(systemName: "stop.fill", help: "Stop scanning", action: manager.stopScan)
                    .keyboardShortcut(.cancelAction)
            } else {
                IconPillButton(systemName: "arrow.clockwise", help: "Rescan (⌘R)") {
                    manager.scan()
                }
            }
            CleanButton(title: "Clean safe items") {
                confirmSafeClean = true
            }
            .disabled(manager.isScanning || manager.safeSize == 0)
        }
    }

    @ViewBuilder
    private var status: some View {
        if manager.isScanning {
            Text("\(manager.progress.done.count) of \(CleanableItemType.allCases.count) categories")
                .monospacedDigit()
        } else if let date = manager.lastScanDate {
            TimelineView(.everyMinute) { _ in
                Text("Scanned \(date.formatted(.relative(presentation: .named).locale(.app)))")
            }
        }
    }

    private var totals: some View {
        let total = manager.isScanning ? manager.progress.totalFound : manager.totalSize
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(total.formatted(.byteCount(style: .file)))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(total)))
                .animation(.default, value: total)
            Text(caption)
                .font(.system(size: 13))
                .foregroundStyle(Theme.Colors.secondaryText)
        }
    }

    private var caption: String {
        if manager.isScanning { return "found so far" }
        guard let free = manager.freeSpace else { return "recoverable" }
        return "recoverable · \(free.formatted(.byteCount(style: .file))) free on this Mac"
    }

    private var scanProgress: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: manager.progress.fractionDone)
                .progressViewStyle(.linear)
                .tint(Theme.Colors.accent)
                .animation(.default, value: manager.progress.fractionDone)
            Label {
                Text(manager.progress.currentPath.abbreviatingHome)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } icon: {
                Image(systemName: "folder")
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.Colors.secondaryText)
        }
    }

    @ViewBuilder
    private var treemap: some View {
        let entries = CleanableItemType.allCases.map { type in
            TreemapView.Entry(
                type: type,
                size: manager.treemapSize(of: type),
                itemCount: manager.categoryStats[type]?.count ?? 0,
                isActive: manager.state(of: type) == .scanning
            )
        }
        if !manager.isScanning && manager.lastScanDate != nil && manager.totalSize == 0 {
            ContentUnavailableView("Nothing to clean", systemImage: "checkmark.circle",
                                   description: Text("No Xcode or Android data was found."))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            TreemapView(entries: entries) { type in
                selection = .category(type)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var safeCleanCard: some View {
        let safeTypes = CleanableItemType.allCases
            .filter { $0.isSafeToDelete && manager.categoryStats[$0] != nil }
            .map(\.title)
            .formatted(.list(type: .and).locale(.app))

        return HStack(spacing: 14) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 16))
                .foregroundStyle(Theme.Colors.safe)
                .frame(width: 32, height: 32)
                .background(Theme.Colors.safeBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(manager.safeSize.formatted(.byteCount(style: .file))) safe to delete")
                    .font(.system(size: 13, weight: .semibold))
                Text("\(safeTypes). Recreated when needed.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.Colors.cardStroke)
        }
    }
}

extension String {
    /// "/Users/me/Library/…" → "~/Library/…"
    var abbreviatingHome: String {
        (self as NSString).abbreviatingWithTildeInPath
    }
}

#Preview {
    OverviewView(selection: .constant(.overview))
        .environment(SimulatorManager())
        .frame(width: 646, height: 600)
}
