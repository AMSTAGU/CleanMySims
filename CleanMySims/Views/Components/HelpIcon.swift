//
//  HelpIcon.swift
//  CleanMySims
//

import SwiftUI

struct HelpIcon: View {
    let tooltip: String
    @State private var isHovering = false

    var body: some View {
        ZStack(alignment: .leading) {
            // Tooltip bubble (positioned to the right)
            if isHovering {
                Text(tooltip)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.primaryText)
                    .padding(12)
                    .frame(width: 220, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(Color.white)
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.15), radius: 8, y: 2)
                    .offset(x: 20, y: 0)
                    .transition(.opacity)
                    .zIndex(100)
            }

            // Question mark icon
            Image(systemName: "questionmark.circle")
                .font(.system(size: 12))
                .foregroundStyle(Theme.Colors.secondaryText)
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}

#Preview {
    VStack(spacing: 50) {
        HelpIcon(tooltip: "Ceci est un texte d'aide explicatif court.")
        HelpIcon(tooltip: "Ceci est un texte d'aide beaucoup plus long qui devrait s'afficher correctement sur plusieurs lignes sans être coupé.")
    }
    .padding(50)
    .background(Theme.Colors.background)
}
