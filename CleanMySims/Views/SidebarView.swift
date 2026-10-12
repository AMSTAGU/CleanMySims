//
//  SidebarView.swift
//  CleanMySims
//

import SwiftUI

enum NavigationItem: Hashable {
    case overview
    case category(CleanableItemType)
}

struct SidebarView: View {
    @Binding var selection: NavigationItem
    @Environment(SimulatorManager.self) private var manager

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            // Room for the traffic lights (hidden title bar)
            Spacer().frame(height: 38)

            SidebarRow(isSelected: selection == .overview, help: nil) {
                selection = .overview
            } icon: {
                GradientIcon(systemName: "square.grid.2x2.fill", color: Theme.Colors.primaryText)
            } label: {
                Text("Overview").fontWeight(.medium)
            } trailing: {
                sizeText(manager.isScanning ? manager.progress.totalFound : manager.totalSize)
            }

            ForEach(Platform.allCases, id: \.self) { platform in
                Text(platform.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .padding(.horizontal, 4)
                    .padding(.top, 14)
                    .padding(.bottom, 3)

                ForEach(CleanableItemType.types(for: platform), id: \.self) { type in
                    categoryRow(type)
                }
            }

            Spacer(minLength: 8)
            footer
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 12)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.Colors.sidebar)
    }

    private func categoryRow(_ type: CleanableItemType) -> some View {
        let state = manager.state(of: type)
        return SidebarRow(isSelected: selection == .category(type), help: type.helpText) {
            selection = .category(type)
        } icon: {
            CategoryIcon(type: type)
        } label: {
            Text(type.shortTitle)
        } trailing: {
            HStack(spacing: 5) {
                switch state {
                case .pending:
                    EmptyView()
                case .scanning:
                    sizeText(manager.size(of: type), color: Theme.Colors.accent)
                    ProgressView().controlSize(.mini)
                case .done:
                    let size = manager.size(of: type)
                    if size > 0 { sizeText(size) } else { sizeText(nil) }
                    if manager.isScanning {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.Colors.safe)
                    }
                }
            }
        }
        .opacity(state == .pending ? 0.5 : 1)
    }

    private func sizeText(_ size: Int64?, color: Color = Theme.Colors.secondaryText) -> some View {
        Text(size.map { $0.formatted(.byteCount(style: .file)) } ?? "—")
            .font(Theme.Fonts.size)
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(color)
            .contentTransition(.numericText())
    }

    private var footer: some View {
        HStack(spacing: 12) {
            Link(destination: URL(string: "https://github.com/AMSTAGU/CleanMySims")!) {
                Image("github").resizable().renderingMode(.template).frame(width: 16, height: 16)
            }
            .help("View on GitHub")
            Link(destination: URL(string: "https://buymeacoffee.com/amstagu")!) {
                Image("coffee").resizable().renderingMode(.template).frame(width: 16, height: 16)
            }
            .help("Buy me a coffee")
            Spacer()
            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                Text("v\(version)")
                    .font(.system(size: 11))
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.Colors.secondaryText)
        .padding(.horizontal, 8)
    }
}

private struct SidebarRow<Icon: View, Label: View, Trailing: View>: View {
    let isSelected: Bool
    let help: String?
    let action: () -> Void
    @ViewBuilder let icon: Icon
    @ViewBuilder let label: Label
    @ViewBuilder let trailing: Trailing

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                icon
                label
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.Colors.primaryText)
                    .lineLimit(1)
                Spacer(minLength: 4)
                trailing
            }
            .padding(.leading, 4)
            .padding(.trailing, 8)
            .padding(.vertical, 3)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(background)
                    .shadow(color: .black.opacity(isSelected ? 0.05 : 0), radius: 2, y: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(help ?? "")
    }

    private var background: Color {
        if isSelected { return Theme.Colors.selection }
        return isHovered ? Theme.Colors.hoverBackground : .clear
    }
}

#Preview {
    SidebarView(selection: .constant(.overview))
        .environment(SimulatorManager())
        .frame(width: 214, height: 600)
}
