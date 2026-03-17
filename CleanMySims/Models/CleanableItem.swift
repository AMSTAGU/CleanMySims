//
//  CleanableItem.swift
//  CleanMySims
//

import Foundation

enum CleanableItemType: String, CaseIterable {
    // iOS / Xcode
    case builds = "Builds"
    case cache = "Caches"
    case deviceSupport = "Device Support"
    case virtualDevice = "Simulators"
    case runtimes = "Runtimes"
    // Android
    case androidEmulator = "Android Emulators"
    case gradleCache = "Gradle"
    case androidStudioCache = "Android Studio"
    case androidSdk = "Android SDK"

    var iconName: String {
        switch self {
        case .cache: return "archivebox"
        case .deviceSupport: return "iphone.circle"
        case .virtualDevice: return "iphone"
        case .runtimes: return "gearshape.2"
        case .builds: return "hammer.circle"
        case .androidEmulator: return "candybarphone"
        case .gradleCache: return "shippingbox"
        case .androidStudioCache: return "wrench.and.screwdriver"
        case .androidSdk: return "cpu"
        }
    }
}

/// Classifies DerivedData entries into logical groups for the Builds tab.
enum BuildGroup: String, CaseIterable, Comparable {
    case apps = "Apps"
    case runners = "Flutter / Runners"
    case xcodeCache = "Xcode Caches"

    var icon: String {
        switch self {
        case .apps: return "app.fill"
        case .runners: return "arrow.triangle.2.circlepath"
        case .xcodeCache: return "memorychip"
        }
    }

    var sortOrder: Int {
        switch self {
        case .apps: return 0
        case .runners: return 1
        case .xcodeCache: return 2
        }
    }

    static func < (lhs: BuildGroup, rhs: BuildGroup) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    /// Classifies a DerivedData folder name into a group.
    static func classify(folderName: String) -> BuildGroup {
        // Caches: names ending in .noindex
        if folderName.hasSuffix(".noindex") {
            return .xcodeCache
        }
        // Runners: Flutter/React Native projects
        let baseName = folderName.components(separatedBy: "-").first ?? folderName
        if baseName == "Runner" {
            return .runners
        }
        return .apps
    }
}

struct CleanableItem: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    let size: Int64
    let type: CleanableItemType
    let isDirectory: Bool
    let details: String?
    let appIconPath: String?
    let buildGroup: BuildGroup?

    var sizeString: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

