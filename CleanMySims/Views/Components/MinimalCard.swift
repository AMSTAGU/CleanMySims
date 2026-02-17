//
//  MinimalCard.swift
//  CleanMySims
//

import SwiftUI

struct MinimalCard: View {
    let title: String
    let type: CleanableItemType
    let size: Int64
    let helpText: String

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

            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.secondaryText)
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .background(VisualEffectBlur(material: .contentBackground, blendingMode: .withinWindow))
        .cornerRadius(Theme.Layout.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Layout.cardCornerRadius)
                .stroke(Theme.Colors.border, lineWidth: 1)
        )
    }
}

#Preview {
    MinimalCard(
        title: "Caches",
        type: .cache,
        size: 4_200_000_000,
        helpText: "Données temporaires des simulateurs"
    )
    .padding()
    .frame(width: 200)
    .background(Theme.Colors.background)
}
