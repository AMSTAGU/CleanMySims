//
//  DetailListView.swift
//  CleanMySims
//

import SwiftUI

struct DetailListView: View {
    let category: CleanableItemType
    @Environment(SimulatorManager.self) private var manager
    @State private var sortOrder: SortOrder = .sizeDescending
    @State private var itemToDelete: CleanableItem?
    @State private var confirmCleanAll = false

    enum SortOrder {
        case sizeDescending, sizeAscending, name

        var label: String {
            switch self {
            case .sizeDescending: return "Largest first"
            case .sizeAscending: return "Smallest first"
            case .name: return "By name"
            }
        }

        var icon: String {
            switch self {
            case .sizeDescending: return "arrow.down"
            case .sizeAscending: return "arrow.up"
            case .name: return "arrow.up.arrow.down"
            }
        }

        var next: SortOrder {
            switch self {
            case .sizeDescending: return .sizeAscending
            case .sizeAscending: return .name
            case .name: return .sizeDescending
            }
        }
    }

    private var items: [CleanableItem] {
        let items = manager.items(of: category)
        switch sortOrder {
        case .name: return items
        case .sizeDescending: return items.sorted { $0.size > $1.size }
        case .sizeAscending: return items.sorted { $0.size < $1.size }
        }
    }

    var body: some View {
        let items = items
        let total = items.reduce(0) { $0 + $1.size }

        VStack(alignment: .leading, spacing: 14) {
            header(items: items, total: total)

            Text(category.helpText)
                .font(.system(size: 12))
                .foregroundStyle(Theme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            if items.isEmpty {
                emptyState
            } else {
                list(items)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 18)
        .padding(.bottom, 22)
        .alert(
            "Delete \(itemToDelete?.name ?? "item")?",
            isPresented: Binding(get: { itemToDelete != nil }, set: { if !$0 { itemToDelete = nil } }),
            presenting: itemToDelete
        ) { item in
            Button("Delete", role: .destructive) { manager.delete(item) }
        } message: { item in
            Text("\(item.sizeString). \(category.removalNote)")
        }
        .alert("Clean all \(category.title.lowercased())?", isPresented: $confirmCleanAll) {
            Button("Clean", role: .destructive) { manager.clean(items) }
        } message: {
            Text("^[\(items.count) item](inflect: true), \(total.formatted(.byteCount(style: .file))). \(category.removalNote)")
        }
    }

    // MARK: - Header

    private func header(items: [CleanableItem], total: Int64) -> some View {
        HStack(spacing: 12) {
            CategoryIcon(type: category, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(category.title)
                        .font(.system(size: 17, weight: .semibold))
                    if category.isSafeToDelete {
                        SafeBadge()
                    }
                }
                Text("^[\(items.count) item](inflect: true)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Colors.secondaryText)
            }
            Spacer()
            IconPillButton(systemName: sortOrder.icon, help: sortOrder.label) {
                withAnimation(.easeInOut(duration: 0.2)) { sortOrder = sortOrder.next }
            }
            SizePill(size: total)
            CleanButton {
                confirmCleanAll = true
            }
            .disabled(items.isEmpty || manager.isScanning)
        }
    }

    // MARK: - List

    @ViewBuilder
    private func list(_ items: [CleanableItem]) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                if category == .builds {
                    let groups = Dictionary(grouping: items) { $0.buildGroup ?? .apps }
                    ForEach(groups.keys.sorted(), id: \.self) { group in
                        let groupItems = groups[group] ?? []
                        Section {
                            rows(groupItems)
                        } header: {
                            BuildGroupHeader(group: group, items: groupItems)
                        }
                    }
                } else {
                    rows(items)
                }
            }
        }
        .scrollIndicators(.automatic)
        .background(Theme.Colors.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.Colors.cardStroke)
        }
    }

    private func rows(_ items: [CleanableItem]) -> some View {
        ForEach(items) { item in
            DetailRow(item: item, isFirst: item.id == items.first?.id) {
                itemToDelete = item
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        Group {
            if manager.state(of: category) != .done {
                ProgressView("Scanning…")
            } else {
                ContentUnavailableView("All clean", systemImage: "checkmark.circle",
                                       description: Text("Nothing to remove here."))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct DetailRow: View {
    let item: CleanableItem
    let isFirst: Bool
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            AsyncIconView(itemPath: item.path, appIconPath: item.appIconPath)
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            Text(item.sizeString)
                .font(Theme.Fonts.size)
                .foregroundStyle(Theme.Colors.secondaryText)

            // Always laid out so rows don't jump on hover
            HStack(spacing: 12) {
                Button(action: reveal) {
                    Image(systemName: "folder")
                        .foregroundStyle(Theme.Colors.reveal)
                }
                .help("Reveal in Finder")
                .disabled(item.path.isEmpty)
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(Theme.Colors.danger)
                }
                .help("Delete")
            }
            .font(.system(size: 14))
            .buttonStyle(.plain)
            .opacity(isHovered ? 1 : 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(isHovered ? Theme.Colors.hoverBackground.opacity(0.6) : .clear)
        .overlay(alignment: .top) {
            if !isFirst {
                Rectangle().fill(Theme.Colors.border).frame(height: 1).padding(.leading, 54)
            }
        }
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .help(item.path)
        .contextMenu {
            Button("Reveal in Finder", action: reveal)
            Button("Delete…", role: .destructive, action: onDelete)
        }
    }

    private var subtitle: String {
        item.details ?? item.path.abbreviatingHome
    }

    private func reveal() {
        NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
    }
}

private struct BuildGroupHeader: View {
    let group: BuildGroup
    let items: [CleanableItem]

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: group.icon)
                .foregroundStyle(Theme.Colors.secondaryText)
            Text(group.rawValue)
                .fontWeight(.semibold)
            Text("\(items.count)")
                .foregroundStyle(Theme.Colors.secondaryText)
            Spacer()
            Text(items.reduce(0) { $0 + $1.size }.formatted(.byteCount(style: .file)))
                .font(Theme.Fonts.size)
                .foregroundStyle(Theme.Colors.secondaryText)
        }
        .font(.system(size: 12))
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.Colors.border).frame(height: 1)
        }
    }
}

#Preview {
    DetailListView(category: .testClones)
        .environment(SimulatorManager())
        .frame(width: 646, height: 600)
}
