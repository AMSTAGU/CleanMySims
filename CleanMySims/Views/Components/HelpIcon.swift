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
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovering = hovering
                }
            }
            .popover(isPresented: $isHovering, arrowEdge: .trailing) {
                Text(tooltip)
                    .font(Theme.Fonts.caption)
                    .foregroundStyle(Theme.Colors.primaryText)
                    .padding(12)
                    .frame(maxWidth: 200)
                    .background(Color.white)
            }
    }
}

#Preview {
    HelpIcon(tooltip: "Ceci est un texte d'aide explicatif.")
        .padding()
}
