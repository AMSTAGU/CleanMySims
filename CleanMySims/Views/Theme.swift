//
//  Theme.swift
//  CleanMySims
//

import SwiftUI
import AppKit

enum Theme {
    enum Colors {
        // Surfaces: translucent, drawn over the window's material
        static let background = Color.clear
        static let sidebar = Color.primary.opacity(0.03)
        static let card = Color(light: 0xFFFFFF, dark: 0xFFFFFF, lightAlpha: 0.45, darkAlpha: 0.06)
        static let cardStroke = Color(light: 0xFFFFFF, dark: 0xFFFFFF, lightAlpha: 0.8, darkAlpha: 0.1)
        static let border = Color.primary.opacity(0.1)
        static let selection = Color(light: 0xFFFFFF, dark: 0xFFFFFF, lightAlpha: 0.8, darkAlpha: 0.12)
        static let hoverBackground = Color.primary.opacity(0.06)
        /// Fill of the small gray controls (sort, size pill).
        static let control = Color.primary.opacity(0.07)

        // Text
        static let primaryText = Color(light: 0x1D1D1F, dark: 0xF5F5F7)
        static let secondaryText = Color(light: 0x636366, dark: 0xA1A1A6)

        // Semantic
        static let accent = Color(light: 0x0A64D6, dark: 0x0A84FF)
        static let safe = Color(light: 0x248A3D, dark: 0x32D74B)
        static let safeBackground = Color(light: 0x34C759, dark: 0x32D74B).opacity(0.15)
        static let danger = Color(light: 0xFF3B30, dark: 0xFF453A)
        static let reveal = Color(light: 0x007AFF, dark: 0x0A84FF)
        static let success = safe

        /// Category accent: fills the icon squares, same in both appearances.
        static func color(for type: CleanableItemType) -> Color {
            Color(nsColor: nsColor(for: type))
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
        /// Sizes in lists and the sidebar.
        static let size = Font.system(size: 11, design: .monospaced)
    }

    enum Layout {
        static let windowWidth: CGFloat = 860
        static let windowHeight: CGFloat = 600
        static let sidebarWidth: CGFloat = 240
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
    init(light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.isDark ? NSColor(hex: dark, alpha: darkAlpha) : NSColor(hex: light, alpha: lightAlpha)
        })
    }
}
