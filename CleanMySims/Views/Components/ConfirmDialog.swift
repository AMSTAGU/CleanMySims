//
//  ConfirmDialog.swift
//  CleanMySims
//

import SwiftUI

struct ConfirmDialog: View {
    let title: String
    let message: String
    let detail: String?
    let confirmTitle: String
    let isDangerous: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text(title)
                .font(Theme.Fonts.headline)
                .foregroundStyle(Theme.Colors.primaryText)

            if let detail = detail {
                Text(detail)
                    .font(Theme.Fonts.subheadline)
                    .foregroundStyle(Theme.Colors.primaryText)
            }

            Text(message)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.secondaryText)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.plain)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.secondaryText)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)

                Button(confirmTitle) {
                    onConfirm()
                }
                .buttonStyle(.plain)
                .font(Theme.Fonts.body)
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(isDangerous ? Theme.Colors.danger : Theme.Colors.simulator)
                .cornerRadius(Theme.Layout.buttonCornerRadius)
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.15), radius: 20)
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.3)
        ConfirmDialog(
            title: "Supprimer cet element ?",
            message: "2.1 GB seront liberes.",
            detail: "\"iPhone 15 Pro - iOS 17.2\"",
            confirmTitle: "Supprimer",
            isDangerous: true,
            onConfirm: { print("Confirmed") },
            onCancel: { print("Cancelled") }
        )
    }
}
