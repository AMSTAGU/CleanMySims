//
//  DetailListView.swift
//  CleanMySims
//

import SwiftUI

struct DetailListView: View {
    let category: CleanableItemType
    @Environment(SimulatorManager.self) private var simulatorManager
    @State private var sortOrder: SortOrder = .defaultOrder
    @State private var showDeleteConfirm = false
    @State private var itemToDelete: CleanableItem?
    @State private var showCleanAllConfirm = false

    enum SortOrder {
        case defaultOrder
        case sizeDesc
        case sizeAsc

        var label: String {
            switch self {
            case .defaultOrder: return "Default"
            case .sizeAsc: return "Size ↑"
            case .sizeDesc: return "Size ↓"
            }
        }

        var icon: String {
            switch self {
            case .defaultOrder: return "arrow.up.arrow.down"
            case .sizeAsc: return "arrow.up"
            case .sizeDesc: return "arrow.down"
            }
        }

        var next: SortOrder {
            switch self {
            case .defaultOrder: return .sizeDesc
            case .sizeDesc: return .sizeAsc
            case .sizeAsc: return .defaultOrder
            }
        }
    }

    // Compute once, reuse everywhere
    private var currentItems: [CleanableItem] {
        let items = simulatorManager.items.filter { $0.type == category }
        switch sortOrder {
        case .defaultOrder:
            return items
        case .sizeAsc:
            return items.sorted { $0.size < $1.size }
        case .sizeDesc:
            return items.sorted { $0.size > $1.size }
        }
    }

    var body: some View {
        let items = currentItems
        let total = items.reduce(0 as Int64) { $0 + $1.size }

        VStack(spacing: 0) {
            // Header
            HStack {
                Text(category.rawValue)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.Colors.primaryText)

                Spacer()

                HStack(spacing: 12) {
                    // Sort Button (Toggle)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            sortOrder = sortOrder.next
                        }
                    }) {
                        Image(systemName: sortOrder.icon)
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 32, height: 32)
                            .background(Theme.Colors.hoverBackground)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(sortOrder.label)

                    // Size Display
                    Text(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(Theme.Colors.hoverBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.black.opacity(0.05), lineWidth: 1)
                        )
                        .fixedSize()

                    // Clean Button
                    Button(action: {
                        showCleanAllConfirm = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash.fill")
                            Text("Clean")
                                .fontWeight(.semibold)
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .frame(height: 32)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "FF3B30"), Color(hex: "FF3B30").opacity(0.8)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .shadow(color: Color.red.opacity(0.3), radius: 2, y: 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(items.isEmpty)
                    .opacity(items.isEmpty ? 0.5 : 1.0)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)

            // Content
            if items.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.Colors.success)
                    Text("All clean!")
                        .font(Theme.Fonts.headline)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if category == .builds {
                // Grouped display for Builds tab
                let grouped = Dictionary(grouping: items) { $0.buildGroup ?? .apps }
                let sortedGroups = grouped.keys.sorted()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(sortedGroups, id: \.self) { group in
                            if let groupItems = grouped[group] {
                                // Section header
                                SectionHeader(
                                    group: group,
                                    count: groupItems.count,
                                    totalSize: groupItems.reduce(0) { $0 + $1.size }
                                )

                                ForEach(groupItems) { item in
                                    DetailRow(
                                        item: item,
                                        accentColor: Theme.Colors.color(for: category)
                                    ) {
                                        itemToDelete = item
                                        showDeleteConfirm = true
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                // Flat list for other tabs
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(items) { item in
                            DetailRow(
                                item: item,
                                accentColor: Theme.Colors.color(for: category)
                            ) {
                                itemToDelete = item
                                showDeleteConfirm = true
                            }
                        }
                    }
                }
            }
        }

        .overlay {
            if showDeleteConfirm, let item = itemToDelete {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    ConfirmDialog(
                        title: "Delete this item?",
                        message: "\(item.sizeString) will be freed.",
                        detail: "\"\(item.name)\"",
                        confirmTitle: "Delete",
                        isDangerous: true,
                        onConfirm: {
                            simulatorManager.delete(item)
                            showDeleteConfirm = false
                            itemToDelete = nil
                        },
                        onCancel: {
                            showDeleteConfirm = false
                            itemToDelete = nil
                        }
                    )
                }
            }

            if showCleanAllConfirm {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()

                    ConfirmDialog(
                        title: "Clean \(category.rawValue)?",
                        message: "\(items.count) items, \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file)) will be deleted.",
                        detail: nil,
                        confirmTitle: "Clean",
                        isDangerous: true,
                        onConfirm: {
                            simulatorManager.clean(items)
                            showCleanAllConfirm = false
                        },
                        onCancel: {
                            showCleanAllConfirm = false
                        }
                    )
                }
            }
        }
    }
}

struct DetailRow: View {
    let item: CleanableItem
    let accentColor: Color
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            AsyncIconView(
                itemPath: item.path,
                appIconPath: item.appIconPath
            )
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(Theme.Fonts.body.weight(.bold))
                    .foregroundStyle(Theme.Colors.primaryText)
                    .lineLimit(1)

                if let details = item.details {
                    Text(details)
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }

                Text(item.path)
                    .font(.caption2)
                    .foregroundStyle(Theme.Colors.secondaryText.opacity(0.6))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Text(item.sizeString)
                .font(Theme.Fonts.mono)
                .foregroundStyle(Theme.Colors.secondaryText)

            // Actions — ALWAYS present, visibility controlled by opacity (no layout change)
            HStack(spacing: 12) {
                Button(action: {
                    NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                }) {
                    Image(systemName: "folder")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(hex: "007AFF"))
                }
                .buttonStyle(.plain)
                .help("Reveal in Finder")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.Colors.danger)
                }
                .buttonStyle(.plain)
                .help("Delete")
            }
            .opacity(isHovered ? 1 : 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isHovered ? Theme.Colors.hoverBackground : Color.clear)
        .onHover { hovered in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovered
            }
        }
        .overlay(
            Rectangle()
                .fill(Theme.Colors.border)
                .frame(height: 1),
            alignment: .bottom
        )
    }
}


struct SectionHeader: View {
    let group: BuildGroup
    let count: Int
    let totalSize: Int64

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: group.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.Colors.secondaryText)

            Text(group.rawValue)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.Colors.primaryText)

            Text("(\(count))")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.Colors.secondaryText)

            Spacer()

            Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.Colors.secondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Theme.Colors.hoverBackground.opacity(0.5))
        .overlay(
            Rectangle()
                .fill(Theme.Colors.border)
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

#Preview {
    DetailListView(category: .cache)
        .environment(SimulatorManager())
        .frame(width: 600, height: 400)
}
