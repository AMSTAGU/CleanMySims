//
//  CategoryIcon.swift
//  CleanMySims
//

import SwiftUI

/// White SF Symbol on a rounded square filled with a gradient of the category color.
struct CategoryIcon: View {
    let type: CleanableItemType
    var size: CGFloat = 24

    var body: some View {
        GradientIcon(systemName: type.iconName, color: Theme.Colors.color(for: type), size: size)
    }
}

struct GradientIcon: View {
    let systemName: String
    let color: Color
    var size: CGFloat = 24
    /// Glyph size relative to the square. Some symbols fill their box more than others.
    var glyphScale: CGFloat = 0.5

    var body: some View {
        RoundedRectangle(cornerRadius: size / 3, style: .continuous)
            .fill(LinearGradient(colors: [color, color.opacity(0.5)], startPoint: .bottomTrailing, endPoint: .topLeading))
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: systemName)
                    .font(.system(size: size * glyphScale, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
            }
            .accessibilityHidden(true)
    }
}

/// Green "Safe" pill for categories the tools recreate on their own.
struct SafeBadge: View {
    var body: some View {
        Label("Safe", systemImage: "checkmark")
            .font(.system(size: 10, weight: .semibold))
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .foregroundStyle(Theme.Colors.safe)
            .background(Theme.Colors.safeBackground, in: Capsule())
            .help("Recreated automatically when needed")
    }
}
