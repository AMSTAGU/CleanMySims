//
//  SimulatorManager.swift
//  CleanMySims
//
//  Created by Amaury Gau on 23/12/2025.
//

import Foundation
import Combine

class SimulatorManager: ObservableObject {
    @Published var items: [CleanableItem] = []
    @Published var isScanning = false
    @Published var isCleaning = false
    @Published var totalSize: Int64 = 0
    
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
                results.append(CleanableItem(
                    id: itemUrl.path,
                    name: name,
                    path: itemUrl.path,
                    size: size,
                    type: type,
                    isDirectory: (try? itemUrl.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false,
                    details: (type == .runtimes && name != itemUrl.lastPathComponent) ? itemUrl.lastPathComponent : nil // Show original folder name in details if we swapped name
                ))
            }
        }
        
        return results
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
                name: name, // User facing name
                path: folder.path,
                size: size,
                type: .virtualDevice,
                isDirectory: true,
                details: details
            ))
        }
        return results
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
                try? await Task.detached(priority: .background) {
                    if item.isDirectory {
                        try FileManager.default.removeItem(atPath: item.path)
                    } else {
                        try FileManager.default.removeItem(atPath: item.path)
                    }
                }.value
            }

            // Rescan after cleaning
            scan()
        }
    }
}
