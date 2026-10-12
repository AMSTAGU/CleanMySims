//
//  Theme.swift
//  CleanMySims
//

import SwiftUI
import AppKit

enum Theme {
    enum Colors {
        // Surfaces
        static let background = Color(light: 0xF7F7F9, dark: 0x1C1C1E)
        static let sidebar = Color(light: 0xECECEF, dark: 0x232325)
        static let card = Color(light: 0xFFFFFF, dark: 0x2A2A2D)
        static let border = Color(light: 0xE1E1E5, dark: 0x3A3A3D)
        static let selection = Color(light: 0xDCDCE0, dark: 0x3A3A3D)
        static let hoverBackground = Color(light: 0xE6E6EA, dark: 0x313134)
        static let track = Color(light: 0xE3E3E8, dark: 0x2E2E31)

        // Text
        static let primaryText = Color(light: 0x1D1D1F, dark: 0xF5F5F7)
        static let secondaryText = Color(light: 0x636366, dark: 0xA1A1A6)

        // Semantic
        static let accent = Color(light: 0x0A64D6, dark: 0x0A84FF)
        static let safe = Color(light: 0x248A3D, dark: 0x32D74B)
        static let safeBackground = Color(light: 0x34C759, dark: 0x32D74B).opacity(0.15)
        static let danger = Color(light: 0xD70015, dark: 0xFF453A)
        static let success = safe

        /// Category accent: fills the icon squares, same in both appearances.
        static func color(for type: CleanableItemType) -> Color {
            Color(nsColor: nsColor(for: type))
        }

        /// Pastel version of the category color, used behind treemap tiles.
        static func tileBackground(for type: CleanableItemType) -> Color {
            let base = nsColor(for: type)
            return Color(nsColor: NSColor(name: nil) { appearance in
                appearance.isDark
                    ? base.blended(withFraction: 0.72, of: NSColor(hex: 0x1C1C1E)) ?? base
                    : base.blended(withFraction: 0.82, of: .white) ?? base
            })
        }

        private static func nsColor(for type: CleanableItemType) -> NSColor {
            switch type {
            case .testClones: return NSColor(hex: 0x0FA3B1)
            case .runtimes: return NSColor(hex: 0x34A853)
            case .builds: return NSColor(hex: 0xF28C00)
            case .deviceSupport: return NSColor(hex: 0x5E5CE6)
            case .previews: return NSColor(hex: 0xAF52DE)
            case .cache: return NSColor(hex: 0x0A84FF)
            case .archives: return NSColor(hex: 0xA2845E)
            case .virtualDevice: return NSColor(hex: 0xFF375F)
            case .androidSdk: return NSColor(hex: 0x2E9E5B)
            case .androidEmulator: return NSColor(hex: 0x3DDC84)
            case .gradleCache: return NSColor(hex: 0x02A9D9)
            case .androidStudioCache: return NSColor(hex: 0xE8710A)
            }
        }
    }

    enum Fonts {
        static let body = Font.system(size: 13)
        static let caption = Font.system(size: 11)
        static let headline = Font.system(size: 15, weight: .semibold)
    }

    enum Layout {
        static let windowWidth: CGFloat = 860
        static let windowHeight: CGFloat = 600
        static let sidebarWidth: CGFloat = 228
    }
}

/// App appearance, overriding the system one if the user picks Light or Dark.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: Self { self }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }
}

extension Locale {
    /// The UI is English-only: format dates and lists in the app's language so sentences don't mix languages.
    static let app = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
}

extension NSAppearance {
    var isDark: Bool {
        bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

extension Color {
    /// A color that follows the window's appearance.
    init(light: UInt32, dark: UInt32) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            NSColor(hex: appearance.isDark ? dark : light)
        })
    }
}
