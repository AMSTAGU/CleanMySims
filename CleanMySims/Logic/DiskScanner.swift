//
//  DiskScanner.swift
//  CleanMySims
//
//  Finds and measures everything CleanMySims can clean. Runs off the main
//  actor: each category is scanned by its own task (see SimulatorManager.scan).
//

import Foundation
import AppKit

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
        case .agentTemp:
            items = agentTemp()
        case .agentConversations:
            items = agentConversations()
        case .agentCaches:
            items = agentCaches()
        case .agentVMs:
            items = agentVMs()
        case .localModels:
            items = localModels()
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


    // MARK: - AI agents

    /// Apps of the AI tools, by bundle identifier: their icon is shown next to their items, and their
    /// caches are left alone while they are open.
    nonisolated enum AgentApp: String, Sendable {
        case claude = "com.anthropic.claudefordesktop"
        case codex = "com.openai.codex"
        case cursor = "com.todesktop.230313mzl4w4u92"
        case antigravity = "com.google.antigravity"
        case antigravityIDE = "com.google.antigravity-ide"
        case ollama = "com.electron.ollama"
        case lmStudio = "ai.elementlabs.lmstudio"

        var name: String {
            switch self {
            case .claude: return "Claude"
            case .codex: return "Codex"
            case .cursor: return "Cursor"
            case .antigravity: return "Antigravity"
            case .antigravityIDE: return "Antigravity IDE"
            case .ollama: return "Ollama"
            case .lmStudio: return "LM Studio"
            }
        }

        var isRunning: Bool {
            !NSRunningApplication.runningApplications(withBundleIdentifier: rawValue).isEmpty
        }

        /// The app's own icon, as Finder shows it, loaded into the cache. Nil when the app isn't installed.
        var iconPath: String? {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: rawValue) else { return nil }
            IconThumbnailCache.shared.preloadSystemIcon(forPath: url.path)
            return url.path
        }
    }

    private static let claudeHome = home + "/.claude"
    private static let claudeTemp = "/private/tmp/claude-\(getuid())"
    private static let claudeAppSupport = home + "/Library/Application Support/Claude"
    private static let cursorAppSupport = home + "/Library/Application Support/Cursor"
    private static let codexHome = home + "/.codex"
    private static let ollamaModels = home + "/.ollama/models"

    /// Claude Code sessions that may still write to their files: running ones (a live process in
    /// ~/.claude/sessions) and background jobs that are working or waiting for an answer.
    private struct ActiveSessions {
        var ids: Set<String> = []
        var versions: Set<String> = []

        func contains(_ sessionID: String) -> Bool {
            ids.contains { sessionID.hasPrefix($0) }
        }
    }

    private func activeClaudeSessions() -> ActiveSessions {
        var active = ActiveSessions()
        for file in contents(of: Self.claudeHome + "/sessions") where file.pathExtension == "json" {
            guard let json = Self.json(at: file),
                  let pid = (json["pid"] as? NSNumber)?.int32Value,
                  kill(pid, 0) == 0 || errno == EPERM else { continue }
            if let id = json["sessionId"] as? String { active.ids.insert(id) }
            if let version = json["version"] as? String { active.versions.insert(version) }
        }
        for job in contents(of: Self.claudeHome + "/jobs") where isDirectory(job) {
            let state = Self.json(at: job.appendingPathComponent("state.json"))
            guard !["done", "stopped"].contains(state?["state"] as? String ?? "") else { continue }
            active.ids.insert(state?["sessionId"] as? String ?? job.lastPathComponent)
        }
        return active
    }

    /// Project folder names by Claude Code project key ("-Users-me-Developer-My-App" → "My-App"). The key
    /// is the path with every non-alphanumeric character turned into a dash, so it can't just be split:
    /// read the working directory recorded in a conversation, or else find the folder on disk.
    private func claudeProjectNames() -> [String: String] {
        var names: [String: String] = [:]
        for project in contents(of: Self.claudeHome + "/projects") {
            let key = project.lastPathComponent
            let transcripts = contents(of: project.path).filter { $0.pathExtension == "jsonl" }
            let cwd = transcripts.prefix(3).lazy.compactMap { Self.firstValue(of: "cwd", inFileAt: $0) }.first
            names[key] = (cwd ?? Self.path(forProjectKey: key)).map { URL(fileURLWithPath: $0).lastPathComponent }
        }
        return names
    }

    /// Walks down from / matching each folder's dashed name against the key. Nil when the folder is gone.
    private static func path(forProjectKey key: String) -> String? {
        func dashed(_ name: String) -> String {
            String(name.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) && $0.isASCII ? Character($0) : "-" })
        }
        var path = ""
        var rest = Substring(key)
        while !rest.isEmpty {
            let children = (try? FileManager.default.contentsOfDirectory(atPath: path.isEmpty ? "/" : path)) ?? []
            // Longest match first: "My-App" before "My"
            let match = children.map { ($0, "-" + dashed($0)) }
                .filter { rest.hasPrefix($0.1) && (rest.count == $0.1.count || rest.dropFirst($0.1.count).hasPrefix("-")) }
                .max { $0.1.count < $1.1.count }
            guard let (name, prefix) = match else { return nil }
            path += "/" + name
            rest = rest.dropFirst(prefix.count)
        }
        return path.isEmpty ? nil : path
    }

    /// A conversation written to in the last few minutes may belong to a session not registered as running.
    private static func isRecentlyActive(_ url: URL) -> Bool {
        let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        return date.map { Date().timeIntervalSince($0) < 10 * 60 } ?? false
    }

    private func modificationDate(_ url: URL) -> String? {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate?
            .formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(.app))
    }

    /// Scratch folders of finished Claude Code sessions (/tmp/claude-<uid>/<project>/<session>), the
    /// temp folders of finished background jobs, and Codex's temp folders.
    private func agentTemp() -> [CleanableItem] {
        let active = activeClaudeSessions()
        let names = claudeProjectNames()
        let claudeIcon = AgentApp.claude.iconPath
        var results: [CleanableItem] = []

        for project in contents(of: Self.claudeTemp) where project.lastPathComponent.hasPrefix("-") {
            let key = project.lastPathComponent
            for session in contents(of: project.path) where isDirectory(session) {
                guard !Task.isCancelled else { return results }
                let id = session.lastPathComponent
                let transcript = URL(fileURLWithPath: Self.claudeHome + "/projects/\(key)/\(id).jsonl")
                guard !active.contains(id), !Self.isRecentlyActive(transcript) else { continue }
                let size = diskSize(of: session, type: .agentTemp)
                guard size > 0 else { continue }
                let details = ["Claude Code session \(id.prefix(8))", modificationDate(session)].compactMap { $0 }
                results.append(CleanableItem(id: session.path, name: names[key] ?? key, path: session.path, size: size,
                                             type: .agentTemp, details: details.joined(separator: " · "),
                                             appIconPath: claudeIcon))
            }
        }

        for job in contents(of: Self.claudeHome + "/jobs") where isDirectory(job) {
            guard !Task.isCancelled else { return results }
            let state = Self.json(at: job.appendingPathComponent("state.json"))
            guard ["done", "stopped"].contains(state?["state"] as? String ?? "") else { continue }
            let tmp = job.appendingPathComponent("tmp")
            let size = diskSize(of: tmp, type: .agentTemp)
            guard size > 0 else { continue }
            let project = (state?["cwd"] as? String).map { URL(fileURLWithPath: $0).lastPathComponent }
            let summary = (state?["detail"] as? String).map { "Background job: \($0)" } ?? "Claude Code background job"
            results.append(CleanableItem(id: tmp.path, name: project ?? job.lastPathComponent, path: tmp.path, size: size,
                                         type: .agentTemp, details: summary, appIconPath: claudeIcon))
        }

        if !AgentApp.codex.isRunning {
            let codexIcon = AgentApp.codex.iconPath
            for folder in contents(of: "/private/tmp") where folder.lastPathComponent.hasPrefix("codex-") {
                let size = diskSize(of: folder, type: .agentTemp)
                guard size > 0 else { continue }
                let name = folder.lastPathComponent.dropFirst("codex-".count).replacingOccurrences(of: "-", with: " ")
                results.append(CleanableItem(id: folder.path, name: "Codex \(name)", path: folder.path, size: size,
                                             type: .agentTemp, details: "Codex temp folder", appIconPath: codexIcon))
            }
        }
        return results
    }

    /// Conversation history: Claude Code per project, Codex per month, Antigravity's recordings and backup.
    private func agentConversations() -> [CleanableItem] {
        let active = activeClaudeSessions()
        let names = claudeProjectNames()
        var results: [CleanableItem] = []

        let claudeIcon = AgentApp.claude.iconPath
        for project in contents(of: Self.claudeHome + "/projects") where isDirectory(project) {
            guard !Task.isCancelled else { return results }
            let transcripts = contents(of: project.path).filter { $0.pathExtension == "jsonl" }
            // A running session keeps writing its conversation here
            guard !transcripts.contains(where: {
                active.contains($0.deletingPathExtension().lastPathComponent) || Self.isRecentlyActive($0)
            }) else { continue }
            let size = diskSize(of: project, type: .agentConversations)
            guard size > 0 else { continue }
            let key = project.lastPathComponent
            results.append(CleanableItem(
                id: project.path, name: names[key] ?? key, path: project.path, size: size, type: .agentConversations,
                details: transcripts.isEmpty ? "Claude Code" : "Claude Code · \(transcripts.count) conversation\(transcripts.count == 1 ? "" : "s")",
                appIconPath: claudeIcon
            ))
        }

        let codexIcon = AgentApp.codex.iconPath
        let codexRunning = AgentApp.codex.isRunning
        let now = Calendar.current.dateComponents([.year, .month], from: Date())
        for year in contents(of: Self.codexHome + "/sessions") {
            for month in contents(of: year.path) {
                guard !Task.isCancelled else { return results }
                // Codex writes today's conversations in the current month
                if codexRunning && Int(year.lastPathComponent) == now.year && Int(month.lastPathComponent) == now.month { continue }
                let size = diskSize(of: month, type: .agentConversations)
                guard size > 0 else { continue }
                var components = DateComponents()
                components.year = Int(year.lastPathComponent)
                components.month = Int(month.lastPathComponent)
                let name = Calendar.current.date(from: components)?
                    .formatted(Date.FormatStyle().month(.wide).year().locale(.app)) ?? month.lastPathComponent
                results.append(CleanableItem(id: month.path, name: name, path: month.path, size: size,
                                             type: .agentConversations, details: "Codex", appIconPath: codexIcon))
            }
        }
        results += single(Self.codexHome + "/archived_sessions", name: "Archived conversations", type: .agentConversations)
            .map { CleanableItem(id: $0.id, name: $0.name, path: $0.path, size: $0.size, type: $0.type,
                                 details: "Codex", appIconPath: codexIcon) }

        let gemini = Self.home + "/.gemini"
        for (folder, app) in [("antigravity", AgentApp.antigravity), ("antigravity-cli", .antigravity), ("antigravity-ide", .antigravityIDE)]
        where !app.isRunning {
            let details = folder == "antigravity-cli" ? "Antigravity CLI" : app.name
            results += single(gemini + "/\(folder)/browser_recordings", name: "Browser recordings", type: .agentConversations)
                .map { CleanableItem(id: $0.id, name: $0.name, path: $0.path, size: $0.size, type: $0.type,
                                     details: details, appIconPath: app.iconPath) }
        }
        results += single(gemini + "/antigravity-backup", name: "Antigravity backup", type: .agentConversations)
            .map { CleanableItem(id: $0.id, name: $0.name, path: $0.path, size: $0.size, type: $0.type,
                                 details: "Old copy of Antigravity's data", appIconPath: AgentApp.antigravity.iconPath) }
        return results
    }

    /// Older Claude Code versions and the caches of the agent apps that are closed.
    private func agentCaches() -> [CleanableItem] {
        var results: [CleanableItem] = []

        // The installer keeps previous versions; skip the current one and those running sessions use
        let active = activeClaudeSessions()
        let current = URL(fileURLWithPath: Self.home + "/.local/bin/claude").resolvingSymlinksInPath().lastPathComponent
        let claudeIcon = AgentApp.claude.iconPath
        for version in contents(of: Self.home + "/.local/share/claude/versions") {
            let number = version.lastPathComponent
            guard number != current, !active.versions.contains(number), !Task.isCancelled else { continue }
            let size = diskSize(of: version, type: .agentCaches)
            guard size > 0 else { continue }
            results.append(CleanableItem(id: version.path, name: "Claude Code \(number)", path: version.path, size: size,
                                         type: .agentCaches, details: "Older version", appIconPath: claudeIcon))
        }

        let appCaches: [(AgentApp, String, [(path: String, name: String)])] = [
            (.claude, Self.claudeAppSupport, [("Cache", "Web cache"), ("Code Cache", "Code cache"), ("GPUCache", "GPU cache")]),
            (.cursor, Self.cursorAppSupport, [("Cache", "Web cache"), ("Code Cache", "Code cache"), ("GPUCache", "GPU cache"),
                                              ("CachedData", "Cached data"), ("CachedExtensionVSIXs", "Extension downloads"),
                                              ("User/globalStorage/state.vscdb.backup", "Settings database backup")]),
            (.codex, Self.codexHome, [("cache", "Cache")]),
        ]
        for (app, root, folders) in appCaches where !app.isRunning {
            let icon = app.iconPath
            for folder in folders {
                guard !Task.isCancelled else { return results }
                let path = root + "/" + folder.path
                results += single(path, name: folder.name, type: .agentCaches)
                    .map { CleanableItem(id: $0.id, name: $0.name, path: $0.path, size: $0.size, type: $0.type,
                                         details: app.name, appIconPath: icon) }
            }
        }
        return results
    }

    /// The virtual machine Claude runs agents in (vm_bundles), while Claude is closed.
    private func agentVMs() -> [CleanableItem] {
        guard !AgentApp.claude.isRunning else { return [] }
        let icon = AgentApp.claude.iconPath
        return contents(of: Self.claudeAppSupport + "/vm_bundles").compactMap { bundle in
            guard !Task.isCancelled else { return nil }
            let size = diskSize(of: bundle, type: .agentVMs)
            guard size > 0 else { return nil }
            return CleanableItem(id: bundle.path, name: "Claude virtual machine", path: bundle.path, size: size,
                                 type: .agentVMs, details: "Claude · \(bundle.lastPathComponent)", appIconPath: icon)
        }
    }

    /// Models downloaded for Ollama (one per tag), LM Studio and Hugging Face.
    private func localModels() -> [CleanableItem] {
        var results: [CleanableItem] = []

        // Ollama: manifests/<registry>/<namespace>/<model>/<tag> list the blobs of each model
        let ollamaIcon = AgentApp.ollama.iconPath
        for registry in contents(of: Self.ollamaModels + "/manifests") {
            for namespace in contents(of: registry.path) {
                for model in contents(of: namespace.path) {
                    for tag in contents(of: model.path) {
                        guard !Task.isCancelled else { return results }
                        let blobs = Self.ollamaBlobs(manifest: tag)
                        let size = blobs.reduce(0) { $0 + diskSize(of: $1, type: .localModels) }
                        guard size > 0 else { continue }
                        var name = "\(model.lastPathComponent):\(tag.lastPathComponent)"
                        if namespace.lastPathComponent != "library" { name = "\(namespace.lastPathComponent)/\(name)" }
                        if registry.lastPathComponent != "registry.ollama.ai" { name = "\(registry.lastPathComponent)/\(name)" }
                        results.append(CleanableItem(id: tag.path, name: name, path: tag.path, size: size,
                                                     type: .localModels, details: "Ollama", appIconPath: ollamaIcon))
                    }
                }
            }
        }

        // LM Studio: models/<publisher>/<model>, in its current and former folder
        let lmStudioIcon = AgentApp.lmStudio.iconPath
        for root in [Self.home + "/.lmstudio/models", Self.home + "/.cache/lm-studio/models"] {
            for publisher in contents(of: root) {
                results += subdirectories(of: publisher.path, type: .localModels, details: nil)
                    .map { CleanableItem(id: $0.id, name: $0.name, path: $0.path, size: $0.size, type: $0.type,
                                         details: "LM Studio · \(publisher.lastPathComponent)", appIconPath: lmStudioIcon) }
            }
        }

        // Hugging Face: hub/models--org--name
        results += subdirectories(of: Self.home + "/.cache/huggingface/hub", type: .localModels, details: nil) {
            $0.lastPathComponent.hasPrefix("models--") || $0.lastPathComponent.hasPrefix("datasets--")
        }.map { item in
            let parts = item.name.components(separatedBy: "--")
            let kind = parts.first == "datasets" ? "Hugging Face dataset" : "Hugging Face"
            return CleanableItem(id: item.id, name: parts.dropFirst().joined(separator: "/"), path: item.path,
                                 size: item.size, type: item.type, details: kind)
        }
        return results
    }

    /// Blob files an Ollama manifest points to (its config and layers).
    private static func ollamaBlobs(manifest: URL) -> [URL] {
        guard let json = json(at: manifest) else { return [] }
        let layers = (json["layers"] as? [[String: Any]] ?? []) + [json["config"] as? [String: Any] ?? [:]]
        return layers.compactMap { $0["digest"] as? String }.map {
            URL(fileURLWithPath: ollamaModels + "/blobs/" + $0.replacingOccurrences(of: ":", with: "-"))
        }
    }

    // MARK: - Helpers

    private static func json(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    /// First `"key":"value"` in the first 64 KB of a JSON Lines file, without parsing whole lines.
    private static func firstValue(of key: String, inFileAt url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 64 * 1024),
              case let text = String(decoding: data, as: UTF8.self),
              let range = text.range(of: "\"\(key)\":\"") else { return nil }
        let rest = text[range.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        return rest[..<end].replacingOccurrences(of: "\\/", with: "/")
    }

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
        case .agentTemp, .agentCaches, .agentVMs:
            if let app = owningApp(item.path), app.isRunning {
                throw RemovalError(message: "Quit \(app.name) first: it uses these files.")
            }
            try deleteFiles(at: item.path, permanently: true)
        case .agentConversations:
            try deleteFiles(at: item.path, permanently: false)
            return true
        case .localModels:
            if item.path.hasPrefix(ollamaModels + "/") {
                try removeOllamaModel(item)
            } else {
                try deleteFiles(at: item.path, permanently: true)
            }
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

    /// The app whose files these are, when it must be closed to delete them.
    private static func owningApp(_ path: String) -> AgentApp? {
        if path.hasPrefix(claudeAppSupport + "/") { return .claude }
        if path.hasPrefix(cursorAppSupport + "/") { return .cursor }
        if path.hasPrefix(codexHome + "/") || path.hasPrefix("/private/tmp/codex-") { return .codex }
        return nil
    }

    /// Removes the model with `ollama rm`, which keeps the blobs other models share. Without the
    /// command (or its server), does the same by hand: deletes the manifest and the blobs nothing else uses.
    private static func removeOllamaModel(_ item: CleanableItem) throws {
        let manifest = URL(fileURLWithPath: item.path)
        let candidates = ["/usr/local/bin/ollama", "/opt/homebrew/bin/ollama", "/Applications/Ollama.app/Contents/Resources/ollama"]
        if let ollama = candidates.first(where: FileManager.default.isExecutableFile(atPath:)) {
            Shell.run(ollama, arguments: ["rm", item.name])
            if !FileManager.default.fileExists(atPath: manifest.path) { return }
        }

        let blobs = ollamaBlobs(manifest: manifest)
        try deleteFiles(at: manifest.path, permanently: true)
        var used: Set<String> = []
        if let enumerator = FileManager.default.enumerator(at: URL(fileURLWithPath: ollamaModels + "/manifests"),
                                                           includingPropertiesForKeys: nil) {
            for case let other as URL in enumerator {
                used.formUnion(ollamaBlobs(manifest: other).map(\.path))
            }
        }
        for blob in blobs where !used.contains(blob.path) {
            try deleteFiles(at: blob.path, permanently: true)
        }
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
