//
//  DetailListView.swift
//  CleanMySims
//

import SwiftUI

struct DetailListView: View {
    let category: CleanableItemType
    @EnvironmentObject var simulatorManager: SimulatorManager
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

    var filteredItems: [CleanableItem] {
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

    var totalSize: Int64 {
        filteredItems.reduce(0) { $0 + $1.size }
    }

    var accentColor: Color {
        Theme.Colors.color(for: category)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(category.rawValue)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.primaryText)

                Spacer()

                HStack(spacing: 12) {
                    // Sort button
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            sortOrder = sortOrder.next
                        }
                    }) {
                        Image(systemName: sortOrder.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.Colors.secondaryText)
                            .frame(width: 28, height: 28)
                            .background(Theme.Colors.hoverBackground)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help(sortOrder.label)

                    Text(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.Colors.primaryText)

                    // Clean button
                    Button(action: {
                        showCleanAllConfirm = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text("Clean")
                        }
                        .font(Theme.Fonts.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .disabled(filteredItems.isEmpty)
                    .opacity(filteredItems.isEmpty ? 0.5 : 1.0)
                }
            }
            .padding(16)
            .background(Color.white)
            .overlay(
                Rectangle()
                    .fill(Theme.Colors.border)
                    .frame(height: 1),
                alignment: .bottom
            )

            // Content
            if filteredItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.Colors.success)
                    Text("All clean!")
                        .font(Theme.Fonts.headline)
                        .foregroundStyle(Theme.Colors.secondaryText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredItems) { item in
                            DetailRow(
                                item: item,
                                accentColor: accentColor
                            ) {
                                itemToDelete = item
                                showDeleteConfirm = true
                            }
                        }
                    }
                }
            }
        }
        .background(Theme.Colors.background)
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
                            simulatorManager.delete(item: item)
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
                        message: "\(filteredItems.count) items, \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)) will be deleted.",
                        detail: nil,
                        confirmTitle: "Clean",
                        isDangerous: true,
                        onConfirm: {
                            simulatorManager.cleanItems(filteredItems)
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
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(Theme.Fonts.body)
                    .foregroundStyle(Theme.Colors.primaryText)
                    .lineLimit(1)

                HStack(spacing: 8) {
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
            }

            Spacer()

            Text(item.sizeString)
                .font(Theme.Fonts.mono)
                .foregroundStyle(Theme.Colors.secondaryText)

            // Actions (show on hover)
            if isHovered {
                HStack(spacing: 12) {
                    Button(action: {
                        NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                    }) {
                        Image(systemName: "folder")
                            .font(.system(size: 14))
                            .foregroundStyle(accentColor)
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
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isHovered ? Theme.Colors.hoverBackground : Color.clear)
        .onHover { hovered in
            withAnimation(.easeInOut(duration: 0.1)) {
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

#Preview {
    DetailListView(category: .cache)
        .environmentObject(SimulatorManager())
        .frame(width: 600, height: 400)
}
