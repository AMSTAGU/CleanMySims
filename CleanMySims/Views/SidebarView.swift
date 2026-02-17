//
//  SidebarView.swift
//  CleanMySims
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
        case .cache: return "Caches"
        case .devices: return "Simulateurs"
        case .runtimes: return "Runtimes"
        case .builds: return "Builds"
        case .deviceSupport: return "Device Support"
        }
    }

    var icon: String {
        switch self {
        case .dashboard: return "gauge.medium"
        case .cache: return "archivebox"
        case .devices: return "iphone"
        case .runtimes: return "gearshape.2"
        case .builds: return "hammer.circle"
        case .deviceSupport: return "iphone.circle"
        }
    }

    var helpText: String? {
        switch self {
        case .dashboard: return nil
        case .cache: return "Donnees temporaires des simulateurs : logs, caches de compilation, donnees telechargees"
        case .devices: return "Les appareils virtuels iOS utilises par Xcode pour tester vos apps"
        case .runtimes: return "Les versions d'iOS installees pour faire tourner les simulateurs"
        case .builds: return "Donnees de compilation generees par Xcode (DerivedData)"
        case .deviceSupport: return "Fichiers de support pour connecter des iPhone/iPad physiques a Xcode"
        }
    }

    var categoryType: CleanableItemType? {
        switch self {
        case .cache: return .cache
        case .devices: return .virtualDevice
        case .runtimes: return .runtimes
        case .builds: return .builds
        case .deviceSupport: return .deviceSupport
        default: return nil
        }
    }
}

struct SidebarView: View {
    @Binding var selection: NavigationItem?
    @State private var hoveredItem: NavigationItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image("logo")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .cornerRadius(6)
                Text("CleanMySims")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.Colors.primaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Dashboard
            SidebarItem(
                item: .dashboard,
                selection: $selection,
                hoveredItem: $hoveredItem
            )

            // Separator
            Rectangle()
                .fill(Theme.Colors.border)
                .frame(height: 1)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)

            // Categories
            ForEach([NavigationItem.cache, .devices, .runtimes, .builds, .deviceSupport], id: \.self) { item in
                SidebarItem(
                    item: item,
                    selection: $selection,
                    hoveredItem: $hoveredItem
                )
            }

            Spacer()

            // Footer
            VStack(spacing: 8) {
                // Links
                HStack(spacing: 12) {
                    Link(destination: URL(string: "https://github.com/AMSTAGU/CleanMySims")!) {
                        Image("github")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 20, height: 20)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .help("Voir sur GitHub")

                    Link(destination: URL(string: "https://buymeacoffee.com/amstagu")!) {
                        Image("coffee")
                            .resizable()
                            .renderingMode(.template)
                            .frame(width: 20, height: 20)
                            .foregroundStyle(Theme.Colors.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .help("Offrir un café")
                }

                // Version
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    Text("v\(version)")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.Colors.secondaryText.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 16)
        }
        .background(Theme.Colors.sidebarBackground)
    }
}

struct SidebarItem: View {
    let item: NavigationItem
    @Binding var selection: NavigationItem?
    @Binding var hoveredItem: NavigationItem?
    @State private var isHelpHovered = false

    private var isSelected: Bool {
        selection == item
    }

    private var isHovered: Bool {
        hoveredItem == item && !isSelected
    }

    private var accentColor: Color {
        if let type = item.categoryType {
            return Theme.Colors.color(for: type)
        }
        return Theme.Colors.primaryText
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.icon)
                .font(.system(size: 16))
                .foregroundStyle(isSelected ? accentColor : Theme.Colors.secondaryText)
                .frame(width: 20)

            Text(item.label)
                .font(Theme.Fonts.body)
                .foregroundStyle(isSelected ? Theme.Colors.primaryText : Theme.Colors.secondaryText)

            Spacer()

            if let helpText = item.helpText {
                HelpIcon(tooltip: helpText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            ZStack(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(accentColor.opacity(0.15))
                        .padding(.horizontal, 8)

                    Rectangle()
                        .fill(accentColor)
                        .frame(width: 3)
                        .padding(.leading, 8)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.Colors.hoverBackground)
                        .padding(.horizontal, 8)
                }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selection = item
        }
        .onHover { hovering in
            hoveredItem = hovering ? item : nil
        }
    }
}

#Preview {
    SidebarView(selection: .constant(.dashboard))
        .frame(width: 200, height: 400)
}
