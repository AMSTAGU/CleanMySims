//
//  HelpIcon.swift
//  CleanMySims
//

import SwiftUI

struct HelpIcon: View {
    let tooltip: String
    @State private var isHovering = false

    var body: some View {
        Image(systemName: "questionmark.circle")
            .font(.system(size: 12))
            .foregroundStyle(Theme.Colors.secondaryText)
            .onHover { hovering in
                isHovering = hovering
            }
            .popover(
                isPresented: $isHovering,
                attachmentAnchor: .point(.trailing),
                arrowEdge: .trailing
            ) {
                Text(tooltip)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.primaryText)
                    .padding(12)
                    .frame(width: 200)
                    .fixedSize(horizontal: false, vertical: true)
            }
    }
}

#Preview {
    VStack(spacing: 50) {
        HStack {
            Text("Caches")
            HelpIcon(tooltip: "Ceci est un texte d'aide explicatif court.")
        }
        HStack {
            Text("Simulateurs")
            HelpIcon(tooltip: "Ceci est un texte d'aide beaucoup plus long.")
        }
    }
    .padding(50)
    .background(Theme.Colors.background)
}
