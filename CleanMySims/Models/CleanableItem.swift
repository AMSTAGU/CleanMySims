//
//  CleanableItem.swift
//  CleanMySims
//
//  Created by Amaury Gau on 23/12/2025.
//

import Foundation

enum CleanableItemType: String, Identifiable, CaseIterable {
    case cache = "Derived Data & Caches"
    case deviceSupport = "iOS Device Support"
    case virtualDevice = "Simulator Devices"
    case runtimes = "iOS Versions"
    case builds = "Builds (Derived Data)"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .cache: return "trash.circle.fill"
        case .deviceSupport: return "iphone.circle.fill"
        case .virtualDevice: return "platter.2.filled.iphone"
        case .runtimes: return "gearshape.2.fill"
        case .builds: return "hammer.circle.fill"
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
    
    // For SwiftUI listing
    var sizeString: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}
