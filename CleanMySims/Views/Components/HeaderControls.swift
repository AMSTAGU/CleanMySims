//
//  HeaderControls.swift
//  CleanMySims
//

import SwiftUI

/// Small gray square button with an icon (sort, rescan…).
struct IconPillButton: View {
    let systemName: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.Colors.primaryText)
                .frame(width: 32, height: 32)
                .background(Theme.Colors.control, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }
}

/// Gray rounded label showing a size.
struct SizePill: View {
    let size: Int64
    var isEstimate = false

    var body: some View {
        Text((isEstimate ? "≈ " : "") + size.formatted(.byteCount(style: .file)))
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .foregroundStyle(Theme.Colors.secondaryText)
            .contentTransition(.numericText())
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Theme.Colors.control, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .fixedSize()
    }
}

/// Red capsule with a trash icon, for destructive actions.
struct CleanButton: View {
    var title = "Clean"
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "trash.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(height: 32)
                .background(
                    Capsule().fill(LinearGradient(
                        colors: [Theme.Colors.danger, Theme.Colors.danger.opacity(0.8)],
                        startPoint: .top, endPoint: .bottom
                    ))
                )
                .shadow(color: Theme.Colors.danger.opacity(0.3), radius: 2, y: 1)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.5)
    }
}
