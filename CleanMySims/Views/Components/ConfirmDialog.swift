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
        VStack(spacing: 16) { // Reduced spacing
            // Icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                (isDangerous ? Theme.Colors.danger : Theme.Colors.cache).opacity(0.15),
                                (isDangerous ? Theme.Colors.danger : Theme.Colors.cache).opacity(0.05)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 48, height: 48) // Smaller circle
                
                Image(systemName: isDangerous ? "trash.fill" : "questionmark")
                    .font(.system(size: 20)) // Smaller icon
                    .foregroundStyle(isDangerous ? Theme.Colors.danger : Theme.Colors.cache)
            }
            .padding(.top, 4)

            VStack(spacing: 6) { // Tighter text spacing
                Text(title)
                    .font(.system(size: 15, weight: .bold)) // Slightly smaller title
                    .foregroundStyle(Theme.Colors.primaryText)
                    .multilineTextAlignment(.center)

                if let detail = detail {
                    Text(detail)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.Colors.primaryText.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Theme.Colors.background.opacity(0.5))
                        .cornerRadius(6)
                }

                Text(message)
                    .font(.system(size: 12)) // Smaller body text
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.Colors.secondaryText)
                        .padding(.horizontal, 16)
                        .frame(height: 32) // Smaller button height
                        .background(Color.black.opacity(0.05))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button(action: onConfirm) {
                    Text(confirmTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .frame(height: 32)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: isDangerous ?
                                            [Color(hex: "FF3B30"), Color(hex: "FF3B30").opacity(0.8)] :
                                            [Theme.Colors.cache, Theme.Colors.cache.opacity(0.8)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .shadow(
                            color: (isDangerous ? Color.red : Theme.Colors.cache).opacity(0.25),
                            radius: 4, y: 2
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 4)
        }
        .padding(20) // Reduced container padding
        .frame(width: 280) // Reduced width (was 340)
        .background(
            ZStack {
                VisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                Color.white.opacity(0.4)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 30, y: 15)
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
