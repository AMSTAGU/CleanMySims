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
    private static let avdPath = home + "/.android/avd"
    private static let dyldCachesPath = "/Library/Developer/CoreSimulator/Caches/dyld"
    private static let runtimePrefix = "com.apple.CoreSimulator.SimRuntime."

    /// How many files to measure between two progress events.
    private static let reportEvery = 2_000

    func scan(_ type: CleanableItemType) -> [CleanableItem] {
        let items: [CleanableItem]
        switch type {
        case .cache:
            items = dyldCaches()
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
    private func diskSize(of url: URL, type: CleanableItemType) -> Int64 {
        measure(url, type: type, exclusive: false).allocated
    }

    /// Allocated size and, with `exclusive`, the part not shared with APFS clones: what deleting
    /// this item alone frees. Simulators are cloned (parallel testing, previews), so their files
    /// share most of their blocks and the allocated sizes add up to far more than the disk holds.
    /// Reports progress (exclusive bytes when measured) every few thousand files and stops early
    /// when the scan is cancelled.
    private func measure(_ url: URL, type: CleanableItemType, exclusive: Bool) -> (allocated: Int64, exclusive: Int64) {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isDirectoryKey]
        let values = try? url.resourceValues(forKeys: Set(keys))
        guard values?.isDirectory == true else {
            let size = Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
            let own = exclusive ? (Self.privateSize(url.path) ?? size) : size
            report(.measured(type, bytes: own, path: url.path))
            return (size, own)
        }

        guard let enumerator = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: keys, options: [], errorHandler: { _, _ in true }
        ) else { return (0, 0) }

        var allocated: Int64 = 0
        var own: Int64 = 0
        var unreported: Int64 = 0
        var count = 0
        for case let fileURL as URL in enumerator {
            if let v = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]),
               let size = v.totalFileAllocatedSize ?? v.fileAllocatedSize {
                let fileOwn = exclusive ? (Self.privateSize(fileURL.path) ?? Int64(size)) : Int64(size)
                allocated += Int64(size)
                own += fileOwn
                unreported += fileOwn
            }
            count += 1
            if count % Self.reportEvery == 0 {
                if Task.isCancelled { break }
                report(.measured(type, bytes: unreported, path: fileURL.path))
                unreported = 0
            }
        }
        report(.measured(type, bytes: unreported, path: url.path))
        return (allocated, own)
    }

    /// Bytes of a file not shared with any APFS clone (ATTR_CMNEXT_PRIVATESIZE), nil if unsupported.
    private static func privateSize(_ path: String) -> Int64? {
        var request = attrlist(
            bitmapcount: u_short(ATTR_BIT_MAP_COUNT), reserved: 0,
            commonattr: attrgroup_t(truncatingIfNeeded: ATTR_CMN_RETURNED_ATTRS),
            volattr: 0, dirattr: 0, fileattr: 0,
            forkattr: attrgroup_t(truncatingIfNeeded: ATTR_CMNEXT_PRIVATESIZE)
        )
        struct Reply {
            var length: UInt32 = 0
            var returned = attribute_set_t()
            var privateSize: off_t = 0
        }
        var reply = Reply()
        let options = UInt32(truncatingIfNeeded: FSOPT_ATTR_CMN_EXTENDED) | UInt32(truncatingIfNeeded: FSOPT_NOFOLLOW)
        let status = withUnsafeMutableBytes(of: &reply) {
            getattrlist(path, &request, $0.baseAddress, $0.count, options)
        }
        guard status == 0,
              reply.returned.forkattr & attrgroup_t(truncatingIfNeeded: ATTR_CMNEXT_PRIVATESIZE) != 0 else { return nil }
        return Int64(reply.privateSize)
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
            let size = measure(folder, type: type, exclusive: true)
            // Leftover empty folders aren't worth listing
            guard size.allocated > 0 || info != nil else { return nil }

            let udid = folder.lastPathComponent
            var details = info?.runtime
            if type != .virtualDevice {
                // Xcode gives every clone the same name: add the UDID prefix to tell them apart
                details = [details, String(udid.prefix(8))].compactMap { $0 }.joined(separator: " · ")
            }
            var item = CleanableItem(id: udid, name: info?.name ?? "Device \(udid.prefix(8))",
                                     path: folder.path, size: size.allocated, type: type, details: details)
            item.exclusiveSize = size.exclusive
            // Clones of the same device type and runtime share their blocks
            item.cloneGroup = info.map { "\($0.deviceType)|\($0.runtime)" }
            return item
        }
    }

    private func deviceInfo(at folder: URL) -> (name: String, runtime: String, deviceType: String)? {
        guard let plist = Self.plist(at: folder.appendingPathComponent("device.plist")),
              let name = plist["name"] as? String,
              let runtimeID = plist["runtime"] as? String else { return nil }
        return (name, Self.runtimeName(fromIdentifier: runtimeID), plist["deviceType"] as? String ?? "")
    }

    /// com.apple.CoreSimulator.SimRuntime.iOS-26-2 → "iOS 26.2"
    static func runtimeName(fromIdentifier identifier: String) -> String {
        let last = identifier.components(separatedBy: ".").last ?? identifier
        var parts = last.components(separatedBy: "-")
        guard parts.count > 1 else { return last }
        let platform = parts.removeFirst()
        return platform + " " + parts.joined(separator: ".")
    }

    /// Simulator system caches: Caches/dyld/<host build>/<runtime identifier>.<runtime build>.
    /// The folders belong to root, so they are listed per runtime and removed with simctl.
    private func dyldCaches() -> [CleanableItem] {
        var results: [CleanableItem] = []
        for host in contents(of: Self.dyldCachesPath) {
            for folder in contents(of: host.path) where folder.lastPathComponent.hasPrefix(Self.runtimePrefix) {
                guard !Task.isCancelled else { return results }
                guard let runtime = Self.dyldCacheRuntime(folder) else { continue }
                let size = diskSize(of: folder, type: .cache)
                guard size > 0 else { continue }
                results.append(CleanableItem(
                    id: folder.path, name: "\(Self.runtimeName(fromIdentifier: runtime.identifier)) system cache",
                    path: folder.path, size: size, type: .cache, details: "dyld shared cache · \(runtime.build)"
                ))
            }
        }
        return results
    }

    /// "com.apple.CoreSimulator.SimRuntime.iOS-18-6.22G86" → (identifier without the build, build)
    private static func dyldCacheRuntime(_ folder: URL) -> (identifier: String, build: String)? {
        var parts = folder.lastPathComponent.components(separatedBy: ".")
        guard parts.count > 1 else { return nil }
        let build = parts.removeLast()
        return (parts.joined(separator: "."), build)
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
        var results: [CleanableItem] = []
        for entry in contents(of: Self.avdPath) {
            guard !Task.isCancelled else { break }
            let avdName = entry.deletingPathExtension().lastPathComponent
            if entry.pathExtension == "avd" {
                let size = diskSize(of: entry, type: .androidEmulator)
                guard size > 0 else { continue }
                results.append(CleanableItem(id: entry.path, name: avdDisplayName(entry) ?? avdName,
                                             path: entry.path, size: size, type: .androidEmulator,
                                             details: "Android Emulator"))
            } else if entry.pathExtension == "ini",
                      !FileManager.default.fileExists(atPath: Self.avdPath + "/\(avdName).avd") {
                // Leftover of an emulator whose folder was deleted by hand: Android Studio lists it as broken
                results.append(CleanableItem(id: entry.path, name: avdName, path: entry.path,
                                             size: diskSize(of: entry, type: .androidEmulator),
                                             type: .androidEmulator, details: "Broken: its .avd folder is missing"))
            }
        }
        return results
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

    struct RemovalError: LocalizedError {
        let message: String
        var errorDescription: String? { message }

        /// Builds an error from a failed command, keeping its own message when it printed one.
        static func command(_ name: String, _ result: (output: String, status: Int32)) -> RemovalError {
            let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            return RemovalError(message: output.isEmpty ? "\(name) failed (exit code \(result.status))." : output)
        }
    }

    /// Removes an item with the tool that owns it (simctl, avdmanager, sdkmanager). Plain folders are
    /// deleted permanently when the tools recreate them, moved to the Trash otherwise. Blocking.
    /// Throws when nothing was removed, so the item stays listed.
    /// Returns true when the item went to the Trash, where it still takes space.
    @discardableResult
    static func remove(_ item: CleanableItem) throws -> Bool {
        switch item.type {
        case .virtualDevice, .testClones, .previews:
            try removeSimulator(item)
        case .runtimes:
            try removeRuntime(item)
        case .cache:
            if item.path.hasPrefix(dyldCachesPath + "/") {
                try removeDyldCache(item)
            } else {
                try deleteFiles(at: item.path, permanently: true)
            }
        case .builds, .gradleCache, .androidStudioCache:
            try deleteFiles(at: item.path, permanently: true)
        case .deviceSupport, .archives:
            try deleteFiles(at: item.path, permanently: false)
            return true
        case .androidEmulator:
            try removeEmulator(item)
        case .androidSdk:
            return try removeSdkPackage(item)
        }
        return false
    }

    /// Shuts the device down if it is running, then deletes it from its device set (its parent folder).
    /// Never touches the folder by hand: that would leave CoreSimulator with a dangling device.
    private static func removeSimulator(_ item: CleanableItem) throws {
        let setPath = URL(fileURLWithPath: item.path).deletingLastPathComponent().path
        Shell.simctl("--set", setPath, "shutdown", item.id) // Fails harmlessly when already shut down
        let result = Shell.simctl("--set", setPath, "delete", item.id)
        guard result.status == 0 else { throw RemovalError.command("simctl delete", result) }
    }

    /// Runtime volumes are mounted disk images owned by root: only simctl can remove them.
    /// Items from simctl carry the runtime identifier as id; older ones only their mount path.
    private static func removeRuntime(_ item: CleanableItem) throws {
        guard let identifier = item.id.hasPrefix("/") ? runtimeIdentifier(mountPath: item.path) : item.id else {
            throw RemovalError(message: "simctl doesn't list this runtime anymore. Rescan and try again.")
        }
        let result = Shell.simctl("runtime", "delete", identifier)
        guard result.status == 0 else { throw RemovalError.command("simctl runtime delete", result) }
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

    /// System dyld caches belong to root: simctl removes them for one runtime.
    private static func removeDyldCache(_ item: CleanableItem) throws {
        guard let runtime = dyldCacheRuntime(URL(fileURLWithPath: item.path)) else {
            throw RemovalError(message: "Unknown cache folder.")
        }
        let result = Shell.simctl("runtime", "dyld_shared_cache", "remove", runtime.identifier)
        guard result.status == 0, !result.output.contains("Invalid runtime") else {
            throw RemovalError.command("simctl runtime dyld_shared_cache remove", result)
        }
    }

    /// Deletes the AVD with avdmanager, then clears what is left of it (its .avd folder and .ini file),
    /// which is all avdmanager does when it works.
    private static func removeEmulator(_ item: CleanableItem) throws {
        let name = URL(fileURLWithPath: item.path).deletingPathExtension().lastPathComponent
        if let avdmanager = androidTool("avdmanager") {
            Shell.run(avdmanager, arguments: ["delete", "avd", "-n", name], environment: androidToolEnvironment)
        }
        for leftover in [avdPath + "/\(name).avd", avdPath + "/\(name).ini"] where FileManager.default.fileExists(atPath: leftover) {
            try deleteFiles(at: leftover, permanently: false)
        }
    }

    /// Uninstalls with sdkmanager so the SDK Manager stays in sync; moves the folder to the Trash
    /// when sdkmanager isn't installed or can't run.
    private static func removeSdkPackage(_ item: CleanableItem) throws -> Bool {
        let packages = sdkPackages(at: item.path)
        if !packages.isEmpty, let sdkmanager = androidTool("sdkmanager") {
            let result = Shell.run(sdkmanager, arguments: ["--sdk_root=\(androidSdkPath)", "--uninstall"] + packages,
                                   environment: androidToolEnvironment)
            if result.status == 0 && !FileManager.default.fileExists(atPath: item.path) { return false }
        }
        try deleteFiles(at: item.path, permanently: false)
        return true
    }

    /// sdkmanager package paths for a folder: platforms/android-34 → "platforms;android-34",
    /// system-images/android-34/google_apis → one package per ABI folder inside.
    private static func sdkPackages(at path: String) -> [String] {
        guard path.hasPrefix(androidSdkPath + "/") else { return [] }
        let components = path.dropFirst(androidSdkPath.count + 1).split(separator: "/").map(String.init)
        guard components.first == "system-images" else {
            return [components.joined(separator: ";")]
        }
        let abis = (try? FileManager.default.contentsOfDirectory(atPath: path))?.filter { !$0.hasPrefix(".") } ?? []
        return abis.map { (components + [$0]).joined(separator: ";") }
    }

    private static func androidTool(_ name: String) -> String? {
        let path = androidSdkPath + "/cmdline-tools/latest/bin/\(name)"
        return FileManager.default.isExecutableFile(atPath: path) ? path : nil
    }

    /// Apps launched from Finder have no JAVA_HOME: use the JDK bundled with Android Studio.
    private static var androidToolEnvironment: [String: String] {
        if ProcessInfo.processInfo.environment["JAVA_HOME"] != nil { return [:] }
        let studioJDK = "/Applications/Android Studio.app/Contents/jbr/Contents/Home"
        return FileManager.default.fileExists(atPath: studioJDK) ? ["JAVA_HOME": studioJDK] : [:]
    }

    private static func deleteFiles(at path: String, permanently: Bool) throws {
        guard FileManager.default.fileExists(atPath: path) else { return }
        let url = URL(fileURLWithPath: path)
        if permanently {
            try FileManager.default.removeItem(at: url)
        } else {
            try FileManager.default.trashItem(at: url, resultingItemURL: nil)
        }
    }
}
