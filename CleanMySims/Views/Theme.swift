//
//  Theme.swift
//  CleanMySims
//
//  Created by Amaury Gau on 23/12/2025.
//

import SwiftUI

struct Theme {
    struct Colors {
        // Minimalist Solid Background
        static let background = Color(hex: "18181B") // Zinc-900 / Deep Neutral Dark
        
        static let cardBackground = Material.ultraThin
        
        static let primaryText = Color.white
        static let secondaryText = Color.white.opacity(0.7)
        
        static let accentBlue = Color(hex: "3A86FF")
        static let accentPurple = Color(hex: "8338EC")
        static let accentPink = Color(hex: "FF006E")
        static let accentOrange = Color(hex: "FB5607")
        static let accentGreen = Color(hex: "38B000") // Limetree
        
        // Semantic
        static let success = accentGreen
        static let danger = Color(hex: "D90429") // Vivid Red
        static let warning = Color(hex: "FFBE0B")
    }
    
    struct Fonts {
        static let title = Font.system(size: 38, weight: .bold, design: .rounded)
        static let headline = Font.system(size: 24, weight: .semibold, design: .rounded)
        static let subheadline = Font.system(size: 16, weight: .medium, design: .rounded)
        static let body = Font.system(size: 14, weight: .regular, design: .default)
        static let caption = Font.system(size: 12, weight: .medium, design: .default)
        static let mono = Font.system(size: 13, weight: .regular, design: .monospaced)
    }
    
    struct Layout {
        static let cardCornerRadius: CGFloat = 20
        static let padding: CGFloat = 20
    }
}

// Helper for Hex Colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
