//
//  CategoryIcon.swift
//  CleanMySims
//

import SwiftUI

/// White SF Symbol on a rounded square of the category color (System Settings style).
struct CategoryIcon: View {
    let type: CleanableItemType
    var size: CGFloat = 22

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
            .fill(Theme.Colors.color(for: type))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: type.iconName)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(.white)
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
