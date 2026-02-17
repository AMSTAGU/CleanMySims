//
//  CleanableItem.swift
//  CleanMySims
//

import Foundation

enum CleanableItemType: String, CaseIterable {
    case cache = "Caches"
    case deviceSupport = "Device Support"
    case virtualDevice = "Simulateurs"
    case runtimes = "Runtimes"
    case builds = "Builds"

    var iconName: String {
        switch self {
        case .cache: return "archivebox"
        case .deviceSupport: return "iphone.circle"
        case .virtualDevice: return "iphone"
        case .runtimes: return "gearshape.2"
        case .builds: return "hammer.circle"
        }
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

    var sizeString: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
