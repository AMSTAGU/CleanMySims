//
//  LoadingOverlay.swift
//  CleanMySims
//

import SwiftUI

struct LoadingOverlay: View {
    let title: String
    let isIndeterminate: Bool
    var forceComplete: Bool = false

    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .controlSize(.large)
                .tint(Theme.Colors.primaryText)
            
            Text(title)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.secondaryText)
        }
        .padding(40)
        .background(Color.white.opacity(0.95)) // Slightly more opaque to hide behind
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 20, y: 10)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        )
    }
}

#Preview {
    ZStack {
        Color.blue.opacity(0.1)
        LoadingOverlay(title: "Scanning...", isIndeterminate: true)
    }
    .frame(width: 400, height: 300)
}
