//
//  DetailListView.swift
//  CleanMySims
//
//  Created by Amaury Gau on 23/12/2025.
//

import SwiftUI

struct DetailListView: View {
    let category: CleanableItemType
    @EnvironmentObject var simulatorManager: SimulatorManager
    
    enum SortOrder {
        case defaultOrder
        case sizeAsc
        case sizeDesc
        
        var next: SortOrder {
            switch self {
            case .defaultOrder: return .sizeDesc
            case .sizeDesc: return .sizeAsc
            case .sizeAsc: return .defaultOrder
            }
        }
        
        var icon: String {
            switch self {
            case .defaultOrder: return "arrow.up.arrow.down"
            case .sizeDesc: return "arrow.down"
            case .sizeAsc: return "arrow.up"
            }
        }
    }
    
    @State private var sortOrder: SortOrder = .defaultOrder
    
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Stats Header
            HStack {
                Text(category.rawValue)
                    .font(Theme.Fonts.headline)
                    .foregroundStyle(Theme.Colors.primaryText)
                
                Spacer()
                
                HStack(spacing: 15) {
                    // Sort Button
                    Button(action: {
                        withAnimation {
                            sortOrder = sortOrder.next
                        }
                    }) {
                        HStack(spacing: 5) {
                           Image(systemName: sortOrder.icon)
                           if sortOrder != .defaultOrder {
                               Text("Size")
                                   .font(Theme.Fonts.caption)
                           }
                        }
                        .foregroundStyle(Theme.Colors.accentBlue)
                        .padding(6)
                        .background(Theme.Colors.accentBlue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .help("Sort by Size")
                    
                    Text(ByteCountFormatter.string(fromByteCount: filteredItems.reduce(0) { $0 + $1.size }, countStyle: .file))
                        .font(Theme.Fonts.headline)
                        .foregroundStyle(Theme.Colors.accentPink)
                }
            }
            .padding()
            .background(Material.ultraThin)
            
            if filteredItems.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 60))
                        .foregroundStyle(Theme.Colors.success.opacity(0.8))
                    Text("All Clean!")
                        .font(Theme.Fonts.title)
                        .foregroundStyle(Theme.Colors.primaryText)
                    Spacer()
                }
            } else {
                List {
                    ForEach(filteredItems) { item in
                        DetailRow(item: item)
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(Theme.Colors.secondaryText.opacity(0.2))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }
}

struct DetailRow: View {
    let item: CleanableItem
    @EnvironmentObject var simulatorManager: SimulatorManager
    @State private var isHovering = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(Theme.Fonts.subheadline)
                    .foregroundStyle(Theme.Colors.primaryText)
                
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
                .foregroundStyle(Theme.Colors.primaryText.opacity(0.8))
            
            HStack(spacing: 15) {
                Button(action: {
                    NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                }) {
                    Image(systemName: "folder")
                        .foregroundStyle(Theme.Colors.accentBlue)
                }
                .buttonStyle(.plain)
                .help("Show in Finder")
                
                Button(action: {
                    simulatorManager.delete(item: item)
                }) {
                    Image(systemName: "trash")
                        .foregroundStyle(Theme.Colors.danger)
                }
                .buttonStyle(.plain)
                .help("Delete Item")
            }
            .padding(.leading, 10)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isHovering ? Color.white.opacity(0.05) : Color.clear)
        .cornerRadius(8)
        .onHover { hover in
            isHovering = hover
        }
    }
}
