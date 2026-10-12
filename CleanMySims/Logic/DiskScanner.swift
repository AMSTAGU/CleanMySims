//
//  DiskScanner.swift
//  CleanMySims
//
//  Finds and measures everything CleanMySims can clean. Runs off the main
//  actor: each category is scanned by its own task (see SimulatorManager.scan).
//

import Foundation

/// Progress events emitted while scanning, in the order they happen.
nonisolated enum ScanEvent: Sendable {
    case started(CleanableItemType)
    /// `bytes` more were measured; `path` is what is being read right now.
    case measured(CleanableItemType, bytes: Int64, path: String)
    case finished(CleanableItemType, [CleanableItem])
}

nonisolated struct DiskScanner: Sendable {
    let report: @Sendable (ScanEvent) -> Void

    private static let home = FileManager.default.homeDirectoryForCurrentUser.path
    private static let developer = home + "/Library/Developer"
    private static let xcode = developer + "/Xcode"
    private static let androidSdkPath = home + "/Library/Android/sdk"

    /// How many files to measure between two progress events.
    private static let reportEvery = 2_000

    func scan(_ type: CleanableItemType) -> [CleanableItem] {
        let items: [CleanableItem]
        switch type {
        case .cache:
            items = subdirectories(of: "/Library/Developer/CoreSimulator/Caches", type: type, details: "System simulator cache")
                + subdirectories(of: Self.developer + "/CoreSimulator/Caches", type: type, details: "Simulator cache")
                + single(Self.home + "/Library/Caches/com.apple.dt.Xcode", name: "Xcode cache", type: type)
        case .deviceSupport:
            items = ["iOS", "watchOS", "tvOS", "visionOS", "macOS"].flatMap { (platform: String) -> [CleanableItem] in
                subdirectories(of: Self.xcode + "/\(platform) DeviceSupport", type: type, details: platform)
            }
        case .virtualDevice:
            items = deviceSet(at: Self.developer + "/CoreSimulator/Devices", type: type)
        case .runtimes:
            items = runtimes()
        case .builds:
            items = builds()
        case .testClones:
            items = deviceSet(at: Self.developer + "/XCTestDevices", type: type)
        case .previews:
            // The previews device set moved between Xcode versions
            items = deviceSet(at: Self.xcode + "/UserData/Previews/Simulator Devices", type: type)
                + deviceSet(at: Self.xcode + "/UserData/IB Support/Simulator Devices", type: type)
        case .archives:
            items = archives()
        case .androidEmulator:
            items = androidEmulators()
        case .gradleCache:
            items = subdirectories(of: Self.home + "/.gradle/caches", type: type, details: "Gradle cache")
                + subdirectories(of: Self.home + "/.gradle/wrapper/dists", type: type, details: "Gradle distribution")
        case .androidStudioCache:
            items = subdirectories(of: Self.home + "/Library/Caches/Google", type: type, details: "Android Studio cache") {
                $0.lastPathComponent.hasPrefix("AndroidStudio")
            }
        case .androidSdk:
            items = androidSdk()
        }
        return items.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    // MARK: - Measuring

    /// Space the item really takes on disk (allocated size, so sparse and compressed files count right).
    /// Reports progress every few thousand files and stops early when the scan is cancelled.
    private func diskSize(of url: URL, type: CleanableItemType) -> Int64 {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isDirectoryKey]
        let values = try? url.resourceValues(forKeys: Set(keys))
        guard values?.isDirectory == true else {
            let size = Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
            report(.measured(type, bytes: size, path: url.path))
            return size
        }

        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: keys, options: [], errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        var unreported: Int64 = 0
        var count = 0
        for case let fileURL as URL in enumerator {
            if let v = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]),
               let size = v.totalFileAllocatedSize ?? v.fileAllocatedSize {
                total += Int64(size)
                unreported += Int64(size)
            }
            count += 1
            if count % Self.reportEvery == 0 {
                if Task.isCancelled { break }
                report(.measured(type, bytes: unreported, path: fileURL.path))
                unreported = 0
            }
        }
        report(.measured(type, bytes: unreported, path: url.path))
        return total
    }

    private func contents(of path: String) -> [URL] {
        (try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    // MARK: - Generic

    /// One item per entry of `path`.
    private func subdirectories(
        of path: String, type: CleanableItemType, details: String?,
        where include: (URL) -> Bool = { _ in true }
    ) -> [CleanableItem] {
        contents(of: path).compactMap { url in
            guard include(url), !Task.isCancelled else { return nil }
            let size = diskSize(of: url, type: type)
            guard size > 0 else { return nil }
            return CleanableItem(id: url.path, name: url.lastPathComponent, path: url.path,
                                 size: size, type: type, details: details)
        }
    }

    /// The folder at `path` as a single item, if it exists.
    private func single(_ path: String, name: String, type: CleanableItemType) -> [CleanableItem] {
        guard FileManager.default.fileExists(atPath: path) else { return [] }
        let size = diskSize(of: URL(fileURLWithPath: path), type: type)
        guard size > 0 else { return [] }
        return [CleanableItem(id: path, name: name, path: path, size: size, type: type, details: nil)]
    }

    // MARK: - Simulators

    /// Lists the devices of a simctl device set (one folder per device UDID, each with a device.plist).
    private func deviceSet(at setPath: String, type: CleanableItemType) -> [CleanableItem] {
        contents(of: setPath).compactMap { folder in
            // Skip device_set.plist and other loose files
            guard isDirectory(folder), !Task.isCancelled else { return nil }
            let info = deviceInfo(at: folder)
            let size = diskSize(of: folder, type: type)
            // Leftover empty folders aren't worth listing
            guard size > 0 || info != nil else { return nil }

            let udid = folder.lastPathComponent
            var details = info?.runtime
            if type != .virtualDevice {
                // Xcode gives every clone the same name: add the UDID prefix to tell them apart
                details = [details, String(udid.prefix(8))].compactMap { $0 }.joined(separator: " · ")
            }
            return CleanableItem(id: udid, name: info?.name ?? "Device \(udid.prefix(8))",
                                 path: folder.path, size: size, type: type, details: details)
        }
    }

    private func deviceInfo(at folder: URL) -> (name: String, runtime: String)? {
        guard let plist = Self.plist(at: folder.appendingPathComponent("device.plist")),
              let name = plist["name"] as? String,
              let runtimeID = plist["runtime"] as? String else { return nil }
        return (name, Self.runtimeName(fromIdentifier: runtimeID))
    }

    /// com.apple.CoreSimulator.SimRuntime.iOS-26-2 → "iOS 26.2"
    static func runtimeName(fromIdentifier identifier: String) -> String {
        let last = identifier.components(separatedBy: ".").last ?? identifier
        var parts = last.components(separatedBy: "-")
        guard parts.count > 1 else { return last }
        let platform = parts.removeFirst()
        return platform + " " + parts.joined(separator: ".")
    }

    /// Installed simulator runtimes, as simctl sees them. Their disk images live in system
    /// folders, so simctl's own size is both faster and more accurate than walking the mounted volume.
    private func runtimes() -> [CleanableItem] {
        let result = Shell.simctl("runtime", "list", "-j")
        guard result.status == 0,
              let data = result.output.data(using: .utf8),
              let images = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
            // No simctl (Command Line Tools only): fall back to the mounted volumes
            return subdirectories(of: "/Library/Developer/CoreSimulator/Volumes", type: .runtimes, details: nil)
        }

        return images.values.compactMap { image in
            guard let identifier = image["identifier"] as? String,
                  (image["deletable"] as? Bool) ?? true else { return nil }
            let size = (image["sizeBytes"] as? NSNumber)?.int64Value ?? 0
            let runtimeID = image["runtimeIdentifier"] as? String ?? ""
            let name = runtimeID.isEmpty ? identifier : Self.runtimeName(fromIdentifier: runtimeID)
            let path = image["mountPath"] as? String ?? image["path"] as? String ?? ""
            report(.measured(.runtimes, bytes: size, path: path))
            return CleanableItem(id: identifier, name: name, path: path, size: size, type: .runtimes,
                                 details: image["build"] as? String)
        }
    }

    // MARK: - Builds (DerivedData)

    private func builds() -> [CleanableItem] {
        contents(of: Self.xcode + "/DerivedData").compactMap { folder in
            guard !Task.isCancelled else { return nil }
            let size = diskSize(of: folder, type: .builds)
            guard size > 0 else { return nil }

            let folderName = folder.lastPathComponent
            var item = CleanableItem(id: folder.path, name: folderName, path: folder.path, size: size,
                                     type: .builds, details: nil,
                                     buildGroup: BuildGroup.classify(folderName: folderName))
            if let app = findApp(in: folder.appendingPathComponent("Build/Products")) {
                // Show the app name, keep the DerivedData folder name as detail
                item = CleanableItem(id: item.id, name: app.deletingPathExtension().lastPathComponent,
                                     path: item.path, size: size, type: .builds, details: folderName,
                                     appIconPath: Self.preloadedIcon(inApp: app), buildGroup: item.buildGroup)
            }
            return item
        }
    }

    /// First .app in Build/Products/<config>/, simulator builds first.
    private func findApp(in productsURL: URL) -> URL? {
        let configs = contents(of: productsURL.path).sorted {
            let lhsSim = $0.lastPathComponent.contains("iphonesimulator")
            let rhsSim = $1.lastPathComponent.contains("iphonesimulator")
            return lhsSim != rhsSim ? lhsSim : $0.lastPathComponent < $1.lastPathComponent
        }
        for config in configs {
            if let app = contents(of: config.path).first(where: { $0.pathExtension == "app" }) {
                return app
            }
        }
        return nil
    }

    // MARK: - Archives

    /// Lists .xcarchive bundles (Archives/<date>/<name>.xcarchive).
    private func archives() -> [CleanableItem] {
        var results: [CleanableItem] = []
        for day in contents(of: Self.xcode + "/Archives") {
            for archive in contents(of: day.path) where archive.pathExtension == "xcarchive" {
                guard !Task.isCancelled else { return results }
                let size = diskSize(of: archive, type: .archives)
                guard size > 0 else { continue }

                let plist = Self.plist(at: archive.appendingPathComponent("Info.plist"))
                let app = plist?["ApplicationProperties"] as? [String: Any]
                var details: [String] = []
                if let version = app?["CFBundleShortVersionString"] as? String {
                    let build = (app?["CFBundleVersion"] as? String).map { " (\($0))" } ?? ""
                    details.append("v\(version)\(build)")
                }
                if let date = plist?["CreationDate"] as? Date {
                    details.append(date.formatted(date: .abbreviated, time: .omitted))
                }
                let iconPath = (app?["ApplicationPath"] as? String).flatMap {
                    Self.preloadedIcon(inApp: archive.appendingPathComponent("Products").appendingPathComponent($0))
                }

                results.append(CleanableItem(
                    id: archive.path,
                    name: plist?["Name"] as? String ?? archive.deletingPathExtension().lastPathComponent,
                    path: archive.path, size: size, type: .archives,
                    details: details.isEmpty ? nil : details.joined(separator: " · "),
                    appIconPath: iconPath
                ))
            }
        }
        return results
    }

    // MARK: - Android

    private func androidEmulators() -> [CleanableItem] {
        contents(of: Self.home + "/.android/avd").compactMap { avd in
            guard avd.pathExtension == "avd", !Task.isCancelled else { return nil }
            let size = diskSize(of: avd, type: .androidEmulator)
            guard size > 0 else { return nil }
            return CleanableItem(id: avd.path,
                                 name: avdDisplayName(avd) ?? avd.deletingPathExtension().lastPathComponent,
                                 path: avd.path, size: size, type: .androidEmulator, details: "Android Emulator")
        }
    }

    private func avdDisplayName(_ avd: URL) -> String? {
        guard let config = try? String(contentsOf: avd.appendingPathComponent("config.ini"), encoding: .utf8) else { return nil }
        let prefix = "avd.ini.displayname="
        guard let line = config.components(separatedBy: "\n").first(where: { $0.hasPrefix(prefix) }) else { return nil }
        let value = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    private func androidSdk() -> [CleanableItem] {
        var results: [CleanableItem] = []

        // Platforms: platforms/android-34 → "API 34"
        for item in subdirectories(of: Self.androidSdkPath + "/platforms", type: .androidSdk, details: "SDK Platform") {
            results.append(renamed(item, Self.apiLevel(item.name)))
        }
        // Build tools: build-tools/34.0.0
        for item in subdirectories(of: Self.androidSdkPath + "/build-tools", type: .androidSdk, details: "Build Tools") {
            results.append(renamed(item, "Build Tools \(item.name)"))
        }
        // System images: system-images/android-34/google_apis
        for api in contents(of: Self.androidSdkPath + "/system-images") {
            for item in subdirectories(of: api.path, type: .androidSdk, details: "System Image") {
                let variant = item.name.replacingOccurrences(of: "_", with: " ").capitalized
                results.append(renamed(item, "\(Self.apiLevel(api.lastPathComponent)) · \(variant)"))
            }
        }
        return results
    }

    private func renamed(_ item: CleanableItem, _ name: String) -> CleanableItem {
        CleanableItem(id: item.id, name: name, path: item.path, size: item.size, type: item.type, details: item.details)
    }

    /// "android-34" → "API 34", other names unchanged.
    private static func apiLevel(_ folderName: String) -> String {
        if folderName.hasPrefix("android-"), let level = Int(folderName.dropFirst("android-".count)) {
            return "API \(level)"
        }
        return folderName
    }

    // MARK: - Helpers

    private static func plist(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
    }

    /// Finds the icon of an .app bundle and loads its thumbnail into the cache.
    private static func preloadedIcon(inApp app: URL) -> String? {
        guard let path = iconPath(inApp: app) else { return nil }
        IconThumbnailCache.shared.preloadThumbnail(forKey: path, fromPath: path)
        return path
    }

    private static func iconPath(inApp app: URL) -> String? {
        let fm = FileManager.default

        // 1. Info.plist (iOS bundles have it at the root, macOS ones in Contents/)
        for plistURL in [app.appendingPathComponent("Info.plist"), app.appendingPathComponent("Contents/Info.plist")] {
            guard let info = plist(at: plistURL) else { continue }
            let bundleDir = plistURL.deletingLastPathComponent()

            if let iconFile = info["CFBundleIconFile"] as? String {
                let file = iconFile.hasSuffix(".icns") ? iconFile : iconFile + ".icns"
                for candidate in [bundleDir.appendingPathComponent("Resources/\(file)"), bundleDir.appendingPathComponent(file)]
                where fm.fileExists(atPath: candidate.path) {
                    return candidate.path
                }
            }
            if let icons = info["CFBundleIcons"] as? [String: Any],
               let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
               let files = primary["CFBundleIconFiles"] as? [String] {
                for base in files {
                    for suffix in ["@3x.png", "@2x.png", ".png"] {
                        let candidate = app.appendingPathComponent(base + suffix)
                        if fm.fileExists(atPath: candidate.path) { return candidate.path }
                    }
                }
            }
        }

        // 2. Any .icns in Contents/Resources (macOS), AppIcon.icns first
        let resources = (try? fm.contentsOfDirectory(at: app.appendingPathComponent("Contents/Resources"), includingPropertiesForKeys: nil)) ?? []
        if let icns = resources.first(where: { $0.lastPathComponent == "AppIcon.icns" }) ?? resources.first(where: { $0.pathExtension == "icns" }) {
            return icns.path
        }

        // 3. Largest AppIcon*.png at the bundle root (iOS)
        let root = (try? fm.contentsOfDirectory(at: app, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        let pngs = root.filter { $0.pathExtension == "png" && $0.lastPathComponent.hasPrefix("AppIcon") }
        if let best = pngs.max(by: { fileSize($0) < fileSize($1) }) {
            return best.path
        }
        return root.first { $0.pathExtension == "png" && $0.lastPathComponent.lowercased().hasPrefix("icon") }?.path
    }

    private static func fileSize(_ url: URL) -> Int {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
    }

    // MARK: - Removal

    /// Removes an item from disk. Simulators and runtimes go through simctl so CoreSimulator
    /// stays consistent; everything else is moved to the trash. Blocking.
    static func remove(_ item: CleanableItem) {
        switch item.type {
        case .virtualDevice, .testClones, .previews:
            // Each device belongs to a device set (its parent folder)
            let setPath = URL(fileURLWithPath: item.path).deletingLastPathComponent().path
            Shell.simctl("--set", setPath, "delete", item.id)
        case .runtimes:
            // Runtime volumes are mounted disk images owned by root: only simctl can remove them.
            // Items from simctl carry the runtime identifier as id; older ones only their mount path.
            if let identifier = item.id.hasPrefix("/") ? runtimeIdentifier(mountPath: item.path) : item.id {
                Shell.simctl("runtime", "delete", identifier)
                return
            }
        default:
            break
        }

        // Move to trash (also a fallback if simctl left the folder behind)
        guard FileManager.default.fileExists(atPath: item.path) else { return }
        do {
            try FileManager.default.trashItem(at: URL(fileURLWithPath: item.path), resultingItemURL: nil)
        } catch {
            print("Error trashing \(item.path): \(error)")
        }
    }

    private static func runtimeIdentifier(mountPath: String) -> String? {
        let result = Shell.simctl("runtime", "list", "-j")
        guard result.status == 0,
              let data = result.output.data(using: .utf8),
              let images = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else {
            return nil
        }
        return images.values.first { ($0["mountPath"] as? String) == mountPath }?["identifier"] as? String
    }
}
