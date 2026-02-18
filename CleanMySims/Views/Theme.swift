//
//  Theme.swift
//  CleanMySims
//

import SwiftUI

struct Theme {
    struct Colors {
        // Base colors
        static let background = Color(hex: "FAFAFA")
        static let sidebarBackground = Color(hex: "F5F5F5")
        static let primaryText = Color(hex: "2D2D2D")
        static let secondaryText = Color(hex: "6B6B6B")
        static let border = Color(hex: "E5E5E5")
        static let hoverBackground = Color(hex: "EEEEEE")

        // Category accent colors (Vibrant/Neon for "Superwhisper" feel)
        static let cache = Color(hex: "007AFF")        // Vivid Blue (System Blue-ish but brighter)
        static let simulator = Color(hex: "FF2D55")    // Vibrant Pink/Red
        static let runtime = Color(hex: "00C853")      // Vivid Green
        static let build = Color(hex: "FF9500")        // Vivid Orange
        static let deviceSupport = Color(hex: "5856D6") // Vivid Purple

        // Semantic colors
        static let danger = Color(hex: "E88B8B")       // Soft coral
        static let success = Color(hex: "A8D5BA")      // Sage green

        // Helper to get color by type
        static func color(for type: CleanableItemType) -> Color {
            switch type {
            case .cache: return cache
            case .virtualDevice: return simulator
            case .runtimes: return runtime
            case .builds: return build
            case .deviceSupport: return deviceSupport
            }
        }
    }

    struct Fonts {
        static let title = Font.system(size: 32, weight: .bold)
        static let headline = Font.system(size: 16, weight: .medium)
        static let subheadline = Font.system(size: 15, weight: .medium)
        static let body = Font.system(size: 13, weight: .regular)
        static let caption = Font.system(size: 11, weight: .regular)
        static let mono = Font.system(size: 11, weight: .regular, design: .monospaced)
    }

    struct Layout {
        static let windowWidth: CGFloat = 800
        static let windowHeight: CGFloat = 550
        static let sidebarWidth: CGFloat = 200
        static let cardCornerRadius: CGFloat = 12
        static let buttonCornerRadius: CGFloat = 8
        static let padding: CGFloat = 16
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
