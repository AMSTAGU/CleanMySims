//
//  HelpIcon.swift
//  CleanMySims
//

import SwiftUI

struct HelpIcon: View {
    let tooltip: String

    var body: some View {
        Image(systemName: "questionmark.circle")
            .font(.system(size: 12))
            .foregroundStyle(Theme.Colors.secondaryText)
            .help(tooltip)
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
            HelpIcon(tooltip: "Ceci est un texte d'aide beaucoup plus long qui devrait s'afficher correctement sur plusieurs lignes.")
        }
    }
    .padding(50)
    .background(Theme.Colors.background)
}
