//
//  MinimalCard.swift
//  CleanMySims
//

import SwiftUI

struct MinimalCard: View {
    let title: String
    let type: CleanableItemType
    let size: Int64
    let itemCount: Int
    let helpText: String
    var overrideSizeString: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: type.iconName)
                    .font(.system(size: 24))
                    .foregroundStyle(Theme.Colors.color(for: type))
                Spacer()
                HelpIcon(tooltip: helpText)
            }

            Spacer()

            Text(title)
                .font(Theme.Fonts.subheadline)
                .foregroundStyle(Theme.Colors.primaryText)

            Text(overrideSizeString ?? ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.secondaryText)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .background(Color.white.opacity(0.45))
        .cornerRadius(Theme.Layout.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius)
                .stroke(Color.white.opacity(0.8), lineWidth: 1)
        )
    }
}

#Preview {
    MinimalCard(
        title: "Caches",
        type: .cache,
        size: 4_200_000_000,
        itemCount: 12,
        helpText: "Données temporaires des simulateurs"
    )
    .padding()
    .frame(width: 200)
    .background(Theme.Colors.background)
}
