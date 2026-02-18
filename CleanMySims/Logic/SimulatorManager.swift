//
//  SimulatorManager.swift
//  CleanMySims
//
//  Created by Amaury Gau on 23/12/2025.
//

import Foundation
import Combine
import SwiftUI // Required for withAnimation

class SimulatorManager: ObservableObject {
    @Published var items: [CleanableItem] = []
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var totalSize: Int64 = 0
    
    // Global Confirmation State
    @Published var showingConfirmation = false
    @Published var confirmationTitle = ""
    @Published var confirmationMessage = ""
    @Published var confirmationDetail: String? = nil
    @Published var confirmationActionTitle = "Confirm"
    @Published var isConfirmationDangerous = false
    private var pendingConfirmationAction: (() -> Void)?
    
    private let fileManager = FileManager.default
    
    // Paths
    private let runtimesPath = "/Library/Developer/CoreSimulator/Volumes"
    private let derivedDataPath = FileManager.default.homeDirectoryForCurrentUser.path + "/Library/Developer/Xcode/DerivedData"
    private let cachePath = "/Library/Developer/CoreSimulator/Caches"
    private let deviceSupportPath = FileManager.default.homeDirectoryForCurrentUser.path + "/Library/Developer/Xcode/iOS DeviceSupport"
    
    // Structs for parsing simctl output
    struct SimctlRuntimeList: Decodable {
        let runtimes: [SimctlRuntime]
    }
    
    struct SimctlRuntime: Decodable {
        let name: String
        let bundlePath: String?
    }
    
    private func fetchRuntimesMap() -> [String: String] {
        // Run simctl list runtimes -j
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["simctl", "list", "runtimes", "-j"]
        process.standardOutput = pipe
        
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let list = try JSONDecoder().decode(SimctlRuntimeList.self, from: data)
            
            var map: [String: String] = [:]
            for runtime in list.runtimes {
                if let path = runtime.bundlePath {
                    // path looks like: /Library/.../iOS_23C54/...
                    if let volumeName = path.components(separatedBy: "/Volumes/").last?.components(separatedBy: "/").first {
                        map[volumeName] = runtime.name
                    }
                }
            }
            return map
        } catch {
            print("Error fetching runtimes: \(error)")
            return [:]
        }
    }
    
    func scan() {
        isScanning = true
        items = []
        totalSize = 0
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var newItems: [CleanableItem] = []
            
            // 1. Scan Caches
            newItems.append(contentsOf: self.scanDirectory(at: self.cachePath, type: .cache))
            
            // 2. Scan Device Support
            newItems.append(contentsOf: self.scanDirectory(at: self.deviceSupportPath, type: .deviceSupport))
            
            // 3. Scan Virtual Devices (simctl)
            newItems.append(contentsOf: self.scanVirtualDevices())
            
            // 4. Scan runtimes (Volumes)
            newItems.append(contentsOf: self.scanDirectory(at: self.runtimesPath, type: .runtimes))
            
            // 5. Scan Derived Data (Builds)
            newItems.append(contentsOf: self.scanDirectory(at: self.derivedDataPath, type: .builds))
            
            let size = newItems.reduce(0) { $0 + $1.size }
            
            // Pre-load system icons for ALL items (we're on a background thread)
            for item in newItems {
                IconThumbnailCache.shared.preloadSystemIcon(forPath: item.path)
            }
            
            DispatchQueue.main.async {
                self.items = newItems
                self.totalSize = size
                self.isScanning = false
            }
        }
    }
    
    // MARK: - Scanning Logic
    
    private func scanDirectory(at path: String, type: CleanableItemType) -> [CleanableItem] {
        var results: [CleanableItem] = []
        let url = URL(fileURLWithPath: path)
        
        // If scanning runtimes, fetch the map
        let runtimesMap: [String: String] = (type == .runtimes) ? fetchRuntimesMap() : [:]
        
        guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey]) else {
            print("Error accessing directory at \(path). Check permissions.")
            return []
        }
        
        for itemUrl in contents {
            var name = itemUrl.lastPathComponent
            let size = getDirectorySize(url: itemUrl)
            
            // For runtimes, try to get friendly name
            if type == .runtimes, let friendlyName = runtimesMap[name] {
                name = friendlyName
            }
            
            // Filter out small files if necessary, or keep everything
            if size > 0 {
                
                var finalName = name
                var iconPath: String? = nil
                
                if type == .builds {
                    if let details = findAppDetails(in: itemUrl) {
                        finalName = details.name
                        iconPath = details.iconPath
                        // Pre-load thumbnail during scan (background thread — CGImageSource is thread-safe)
                        if let path = iconPath {
                            IconThumbnailCache.shared.preloadThumbnail(forKey: path, fromPath: path)
                        }
                    }
                }
                
                let group: BuildGroup? = (type == .builds) ? BuildGroup.classify(folderName: itemUrl.lastPathComponent) : nil
                
                results.append(CleanableItem(
                    id: itemUrl.path,
                    name: finalName,
                    path: itemUrl.path,
                    size: size,
                    type: type,
                    isDirectory: (try? itemUrl.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false,
                    details: (type == .runtimes && name != itemUrl.lastPathComponent) ? itemUrl.lastPathComponent : (type == .builds && finalName != name) ? name : nil, 
                    appIconPath: iconPath,
                    buildGroup: group
                ))
            }
        }
        
        return results.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    
    private func scanVirtualDevices() -> [CleanableItem] {
        // Use simctl to list devices
        // logic: xcrun simctl list devices -j
        
        // For simplicity and matching user request "unavailable" or specific pattern, 
        // we might initially just look at the directories in ~/Library/Developer/CoreSimulator/Devices
        // But better is to trust simctl.
        
        // Let's implement a safe approach: Check the physical folder size, map to simctl list if possible.
        // User said: xcrun simctl list devices | grep -v ... | xargs delete
        
        // We will list the FOLDERs in Devices dir, and maybe try to parse their status.
        let devicesPath = fileManager.homeDirectoryForCurrentUser.path + "/Library/Developer/CoreSimulator/Devices"
        let url = URL(fileURLWithPath: devicesPath)
        
        var results: [CleanableItem] = []
        guard let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else { return [] }
        
        for folder in contents {
            let size = getDirectorySize(url: folder)
            let infos = getDeviceInfos(url: folder)
            
            // If we have infos, use them. Otherwise default fallback.
            let name = infos?.name ?? "Device " + folder.lastPathComponent.prefix(8)
            let details = infos?.runtime
            
            // Only add if size > 0 or if scanning logic allows empty folders
            // For devices, folder usually exists.
            
            results.append(CleanableItem(
                id: folder.lastPathComponent,
                name: name,
                path: folder.path,
                size: size,
                type: .virtualDevice,
                isDirectory: true,
                details: details,
                appIconPath: nil,
                buildGroup: nil
            ))
        }
        return results.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    private func getDeviceInfos(url: URL) -> (name: String, runtime: String)? {
        let plistUrl = url.appendingPathComponent("device.plist")
        guard let plistData = try? Data(contentsOf: plistUrl),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any],
              let name = plist["name"] as? String,
              let runtimeRaw = plist["runtime"] as? String else {
            return nil
        }
        
        // Parse runtime: com.apple.CoreSimulator.SimRuntime.iOS-26-2 -> iOS 26.2
        var runtime = runtimeRaw.components(separatedBy: ".").last ?? runtimeRaw
        runtime = runtime.replacingOccurrences(of: "-", with: " ") // iOS 26 2
        
        // Try to make it look like "iOS 17.2"
        if let range = runtime.range(of: "\\d+ \\d+", options: .regularExpression) {
             let versionPart = runtime[range]
             let formattedVersion = versionPart.replacingOccurrences(of: " ", with: ".")
             runtime = runtime.replacingOccurrences(of: versionPart, with: formattedVersion)
        }
        
        return (name, runtime)
    }
    
    private func getDirectorySize(url: URL) -> Int64 {
        // Simple recursive calculation
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var size: Int64 = 0
        for case let fileUrl as URL in enumerator {
            if let fileSize = (try? fileUrl.resourceValues(forKeys: [.fileSizeKey]).fileSize) {
                size += Int64(fileSize)
            }
        }
        return size
    }

    private func findAppDetails(in url: URL) -> (name: String, iconPath: String?)? {
        let buildProductsPath = url.appendingPathComponent("Build/Products")
        
        // We only want to look a few levels deep to find the .app
        // Typical path: Build/Products/Debug-iphonesimulator/MyApp.app
        
        guard let contents = try? fileManager.contentsOfDirectory(at: buildProductsPath, includingPropertiesForKeys: nil) else { return nil }
        
        // Prioritize simulator builds
        let sortedContents = contents.sorted {
            if $0.lastPathComponent.contains("iphonesimulator") { return true }
            if $1.lastPathComponent.contains("iphonesimulator") { return false }
            return $0.lastPathComponent < $1.lastPathComponent
        }
        
        for folder in sortedContents {
             guard let products = try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) else { continue }
             for product in products {
                 if product.pathExtension == "app" {
                     let appName = product.deletingPathExtension().lastPathComponent
                     let iconPath = findIconFile(in: product)
                     return (appName, iconPath)
                 }
             }
        }
        
        return nil
    }
    
    private func findIconFile(in appBundleUrl: URL) -> String? {
        // Strategy 1: Check Info.plist for icon file reference (most reliable)
        if let iconFromPlist = findIconFromPlist(in: appBundleUrl) {
            return iconFromPlist
        }
        
        // Strategy 2: Look for .icns files (macOS apps — in Contents/Resources/)
        let resourcesUrl = appBundleUrl.appendingPathComponent("Contents/Resources")
        if let contents = try? fileManager.contentsOfDirectory(at: resourcesUrl, includingPropertiesForKeys: nil) {
            // Prefer AppIcon.icns
            if let appIconIcns = contents.first(where: { $0.lastPathComponent == "AppIcon.icns" }) {
                return appIconIcns.path
            }
            // Any .icns file
            if let anyIcns = contents.first(where: { $0.pathExtension == "icns" }) {
                return anyIcns.path
            }
        }
        
        // Strategy 3: iOS standard — look for common AppIcon PNGs at bundle root
        let commonNames = [
            "AppIcon60x60@2x.png", "AppIcon60x60@3x.png",
            "AppIcon76x76@2x~ipad.png", "AppIcon76x76@2x.png",
            "AppIcon83.5x83.5@2x~ipad.png",
            "AppIcon40x40@2x.png", "AppIcon40x40@3x.png",
            "AppIcon29x29@2x.png", "AppIcon29x29@3x.png",
            "AppIcon20x20@2x.png", "AppIcon20x20@3x.png"
        ]
        for name in commonNames {
            let fileUrl = appBundleUrl.appendingPathComponent(name)
            if fileManager.fileExists(atPath: fileUrl.path) {
                return fileUrl.path
            }
        }
        
        // Strategy 4: Look for ANY file matching AppIcon* pattern (covers non-standard names like AppIcon-Dev60x60@2x.png)
        if let contents = try? fileManager.contentsOfDirectory(at: appBundleUrl, includingPropertiesForKeys: nil) {
            // Prefer largest AppIcon png (better quality)
            let appIcons = contents.filter { 
                $0.lastPathComponent.hasPrefix("AppIcon") && $0.pathExtension == "png" 
            }
            if let best = appIcons.max(by: { fileSize(at: $0) < fileSize(at: $1) }) {
                return best.path
            }
            
            // Any Icon*.png
            if let icon = contents.first(where: {
                $0.lastPathComponent.lowercased().hasPrefix("icon") && $0.pathExtension == "png"
            }) {
                return icon.path
            }
        }
        
        // Strategy 5: Recursive search in bundle (up to 3 levels deep, for unusual structures)
        if let enumerator = fileManager.enumerator(at: appBundleUrl, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            var depth = 0
            for case let fileUrl as URL in enumerator {
                // Limit depth
                let relPath = fileUrl.path.replacingOccurrences(of: appBundleUrl.path, with: "")
                depth = relPath.components(separatedBy: "/").count - 1
                if depth > 3 { enumerator.skipDescendants(); continue }
                
                let name = fileUrl.lastPathComponent
                if name.hasPrefix("AppIcon") && fileUrl.pathExtension == "png" {
                    return fileUrl.path
                }
                if fileUrl.pathExtension == "icns" {
                    return fileUrl.path
                }
            }
        }
        
        return nil
    }
    
    /// Reads Info.plist to find the app icon file path
    private func findIconFromPlist(in appBundleUrl: URL) -> String? {
        // Try iOS-style plist (at bundle root)
        let plistPaths = [
            appBundleUrl.appendingPathComponent("Info.plist"),
            appBundleUrl.appendingPathComponent("Contents/Info.plist")
        ]
        
        for plistUrl in plistPaths {
            guard let data = try? Data(contentsOf: plistUrl),
                  let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
                continue
            }
            
            // Check CFBundleIconFile (macOS) — typically "AppIcon" → look for AppIcon.icns
            if let iconFile = plist["CFBundleIconFile"] as? String {
                let baseName = iconFile.hasSuffix(".icns") ? iconFile : iconFile + ".icns"
                let resourceDir = plistUrl.deletingLastPathComponent()
                
                // Look in Resources directory
                let resourcesPath = resourceDir.appendingPathComponent("Resources").appendingPathComponent(baseName)
                if fileManager.fileExists(atPath: resourcesPath.path) {
                    return resourcesPath.path
                }
                // Look directly next to plist
                let directPath = resourceDir.appendingPathComponent(baseName)
                if fileManager.fileExists(atPath: directPath.path) {
                    return directPath.path
                }
            }
            
            // Check CFBundleIcons > CFBundlePrimaryIcon > CFBundleIconFiles (iOS)
            if let icons = plist["CFBundleIcons"] as? [String: Any],
               let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
               let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String] {
                // iconFiles contains base names like "AppIcon60x60"
                for baseName in iconFiles {
                    // Try with @2x/@3x suffix
                    for suffix in ["@3x.png", "@2x.png", ".png"] {
                        let fullName = baseName + suffix
                        let path = appBundleUrl.appendingPathComponent(fullName)
                        if fileManager.fileExists(atPath: path.path) {
                            return path.path
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    /// Returns the file size (for sorting icon candidates by quality)
    private func fileSize(at url: URL) -> Int64 {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
    }
    
    // MARK: - Cleaning Logic
    
    func delete(item: CleanableItem) {
        if item.type == .virtualDevice {
            // Use simctl
            Shell.run("xcrun simctl delete \(item.id)")
        } else {
            // Move to trash
            do {
                try fileManager.trashItem(at: URL(fileURLWithPath: item.path), resultingItemURL: nil)
            } catch {
                print("Error trashing item: \(error)")
            }
        }
        
        // Remove from list
        DispatchQueue.main.async {
            self.items.removeAll { $0.id == item.id }
            self.totalSize -= item.size
        }
    }
    
    func cleanAll() {
        isCleaning = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Artificial delay for better UX if it's too fast, or just to show the animation
            if self.items.count < 5 {
                Thread.sleep(forTimeInterval: 1.0)
            }

            for item in self.items {
                self.delete(item: item)
                // Small sleep to allow UI to update and show progress if needed
                Thread.sleep(forTimeInterval: 0.1)
            }

            DispatchQueue.main.async {
                self.isCleaning = false
            }
        }
    }

    func cleanItems(_ items: [CleanableItem]) {
        Task { @MainActor in
            isCleaning = true
            defer { isCleaning = false }

            for item in items {
                // Ensure we interact with fileManager on a background thread if needed, or safely here
                // removeItem can throw, so we handle it
                await Task.detached(priority: .background) {
                    do {
                        try FileManager.default.removeItem(atPath: item.path)
                    } catch {
                        print("Failed to delete \(item.path): \(error)")
                    }
                }.value
            }

            // Rescan after cleaning
            scan()
        }
    }

    // MARK: - Global Confirmation Flow
    
    func proposeDelete(item: CleanableItem) {
        confirmationTitle = "Delete this item?"
        confirmationMessage = "\(item.sizeString) will be freed."
        confirmationDetail = "\"\(item.name)\""
        confirmationActionTitle = "Delete"
        isConfirmationDangerous = true
        
        pendingConfirmationAction = { [weak self] in
            self?.delete(item: item)
        }
        
        withAnimation {
            showingConfirmation = true
        }
    }
    
    func proposeClean(items: [CleanableItem]) {
        let size = items.reduce(0) { $0 + $1.size }
        let sizeString = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        
        confirmationTitle = "Clean selected items?"
        confirmationMessage = "\(items.count) items, \(sizeString) will be deleted."
        confirmationDetail = nil
        confirmationActionTitle = "Clean"
        isConfirmationDangerous = true
        
        pendingConfirmationAction = { [weak self] in
            self?.cleanItems(items)
        }
        
        withAnimation {
            showingConfirmation = true
        }
    }
    
    func confirmAction() {
        pendingConfirmationAction?()
        closeConfirmation()
    }
    
    func cancelAction() {
        closeConfirmation()
    }
    
    private func closeConfirmation() {
        withAnimation {
            showingConfirmation = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.pendingConfirmationAction = nil
        }
    }
}
