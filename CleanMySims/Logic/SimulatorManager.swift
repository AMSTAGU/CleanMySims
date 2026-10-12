//
//  SimulatorManager.swift
//  CleanMySims
//
//  Created by Amaury Gau on 23/12/2025.
//

import Foundation
import Observation

@Observable
final class SimulatorManager {
    struct CategoryStats: Equatable {
        var count: Int
        /// Sum of the items' sizes. Overstates clones, which share their blocks.
        var size: Int64
        /// Estimate of what deleting the whole category frees (see `CleanableItem.reclaimableSize`).
        var reclaimable: Int64

        init(_ items: [CleanableItem]) {
            count = items.count
            size = items.reduce(0) { $0 + $1.size }
            reclaimable = CleanableItem.reclaimableSize(of: items)
        }

        /// Clones make the listed sizes add up to much more than what can be freed.
        var isShared: Bool { reclaimable < size * 9 / 10 }
    }

    /// What the last clean did, measured on the disk.
    struct CleanResult: Equatable {
        let removedCount: Int
        /// Free space gained on the volume since the clean started.
        var freed: Int64
        /// Size of the items moved to the Trash: freed only once it is emptied.
        let trashed: Int64
        /// APFS and CoreSimulator release blocks in the background, up to ~20 s after the deletions:
        /// true while the free space is still being watched.
        var isMeasuring: Bool
    }

    enum CategoryState {
        case pending, scanning, done
    }

    /// Live state of the running scan.
    struct ScanProgress {
        var found: [CleanableItemType: Int64] = [:]
        var scanning: Set<CleanableItemType> = []
        var done: Set<CleanableItemType> = []
        var currentPath = ""
        var startedAt = Date()

        var totalFound: Int64 { found.values.reduce(0, +) }
        var fractionDone: Double { Double(done.count) / Double(CleanableItemType.allCases.count) }
    }

    private(set) var items: [CleanableItem] = []
    private(set) var categoryStats: [CleanableItemType: CategoryStats] = [:]
    private(set) var isScanning = false
    private(set) var progress = ScanProgress()
    /// Category sizes for the treemap during a scan, refreshed at most every `treemapRefreshInterval`
    /// so tiles move smoothly instead of jittering on every measured file.
    private(set) var treemapFound: [CleanableItemType: Int64] = [:]
    private(set) var lastScanDate: Date?
    private(set) var freeSpace: Int64?

    private(set) var isCleaning = false
    private(set) var cleaningDone = 0
    private(set) var cleaningTotal = 0
    /// Items the last clean couldn't remove, with the reason. They stay in the lists.
    var cleaningFailures: [(item: CleanableItem, reason: String)] = []
    var lastCleanResult: CleanResult?

    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private var lastTreemapRefresh = Date.distantPast
    @ObservationIgnored private var measureTask: Task<Void, Never>?
    private let treemapRefreshInterval: TimeInterval = 0.8

    /// Estimate of the space all categories free, clones counted once.
    var totalSize: Int64 {
        categoryStats.values.reduce(0) { $0 + $1.reclaimable }
    }

    var safeItems: [CleanableItem] {
        items.filter { $0.type.isSafeToDelete }
    }

    var safeSize: Int64 {
        categoryStats.filter { $0.key.isSafeToDelete }.values.reduce(0) { $0 + $1.reclaimable }
    }

    /// Size to show for a category: the final total once it is scanned, the running count before that.
    func size(of type: CleanableItemType) -> Int64 {
        categoryStats[type]?.reclaimable ?? progress.found[type] ?? 0
    }

    func treemapSize(of type: CleanableItemType) -> Int64 {
        categoryStats[type]?.reclaimable ?? treemapFound[type] ?? 0
    }

    func state(of type: CleanableItemType) -> CategoryState {
        if progress.done.contains(type) || (!isScanning && categoryStats[type] != nil) { return .done }
        if progress.scanning.contains(type) { return .scanning }
        return isScanning ? .pending : .done
    }

    func items(of type: CleanableItemType) -> [CleanableItem] {
        items.filter { $0.type == type }
    }

    // MARK: - Scanning

    /// Scans every category in parallel and streams progress to the UI.
    func scan() {
        scanTask?.cancel()

        items = []
        categoryStats = [:]
        progress = ScanProgress()
        treemapFound = [:]
        isScanning = true

        let (events, continuation) = AsyncStream.makeStream(of: ScanEvent.self)
        let worker = Task.detached(priority: .userInitiated) {
            await withTaskGroup(of: Void.self) { group in
                for type in CleanableItemType.allCases {
                    group.addTask {
                        continuation.yield(.started(type))
                        let items = DiskScanner(report: { continuation.yield($0) }).scan(type)
                        // System icons are drawn in the lists: load them now, off the main thread
                        for item in items where item.appIconPath == nil {
                            IconThumbnailCache.shared.preloadSystemIcon(forPath: item.path)
                        }
                        continuation.yield(.finished(type, items))
                    }
                }
            }
            continuation.finish()
        }

        scanTask = Task { [weak self] in
            await withTaskCancellationHandler {
                for await event in events {
                    self?.apply(event)
                }
            } onCancel: {
                worker.cancel()
            }
            self?.finishScan()
        }
    }

    func stopScan() {
        scanTask?.cancel()
    }

    private func apply(_ event: ScanEvent) {
        switch event {
        case .started(let type):
            progress.scanning.insert(type)
        case .measured(let type, let bytes, let path):
            progress.found[type, default: 0] += bytes
            progress.currentPath = path
            if Date().timeIntervalSince(lastTreemapRefresh) >= treemapRefreshInterval {
                lastTreemapRefresh = Date()
                treemapFound = progress.found
            }
        case .finished(let type, let newItems):
            progress.scanning.remove(type)
            progress.done.insert(type)
            let stats = CategoryStats(newItems)
            progress.found[type] = stats.reclaimable
            treemapFound[type] = stats.reclaimable
            if !newItems.isEmpty {
                items.append(contentsOf: newItems)
                categoryStats[type] = stats
            }
        }
    }

    private func finishScan() {
        isScanning = false
        progress.scanning = []
        lastScanDate = Date()
        refreshFreeSpace()
    }

    private func refreshFreeSpace() {
        let values = try? URL(fileURLWithPath: NSHomeDirectory())
            .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        freeSpace = values?.volumeAvailableCapacityForImportantUsage
    }

    // MARK: - Cleaning

    func delete(_ item: CleanableItem) {
        clean([item])
    }

    /// Removes items one by one off the main thread, updating the lists as it goes.
    /// Items that fail stay listed and are reported in `cleaningFailures`.
    func clean(_ itemsToClean: [CleanableItem]) {
        guard !itemsToClean.isEmpty, !isCleaning else { return }
        isCleaning = true
        cleaningDone = 0
        cleaningTotal = itemsToClean.count
        cleaningFailures = []
        lastCleanResult = nil
        measureTask?.cancel()

        Task {
            let freeBefore = Self.availableBytes()
            var failures: [(item: CleanableItem, reason: String)] = []
            var removed: [CleanableItem] = []
            var trashed: Int64 = 0
            for item in itemsToClean {
                let outcome = await Task.detached(priority: .userInitiated) { () -> Result<Bool, Error> in
                    Result { try DiskScanner.remove(item) }
                }.value
                switch outcome {
                case .success(let wentToTrash):
                    if wentToTrash { trashed += item.size } else { removed.append(item) }
                    forget(item)
                case .failure(let error):
                    failures.append((item, error.localizedDescription))
                }
                cleaningDone += 1
            }
            isCleaning = false
            cleaningFailures = failures
            let removedCount = itemsToClean.count - failures.count
            guard removedCount > 0, let freeBefore else { return }

            lastCleanResult = CleanResult(removedCount: removedCount, freed: 0, trashed: trashed, isMeasuring: true)
            let expected = CleanableItem.reclaimableSize(of: removed)
            measureTask = Task { await measureFreedSpace(since: freeBefore, expected: expected) }
        }
    }

    private func forget(_ item: CleanableItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id && $0.type == item.type }) else { return }
        items.remove(at: index)
        let remaining = items(of: item.type)
        categoryStats[item.type] = remaining.isEmpty ? nil : CategoryStats(remaining)
    }

    /// Watches the free space after a clean until it stops growing (blocks are released in the
    /// background), so the banner shows what was really gained.
    private func measureFreedSpace(since freeBefore: Int64, expected: Int64) async {
        let start = Date()
        var lastGrowth = Date()
        var freed: Int64 = 0
        while expected > 50_000_000, Date().timeIntervalSince(start) < 60, !Task.isCancelled {
            try? await Task.sleep(for: .seconds(2))
            guard let now = Self.availableBytes() else { break }
            let current = max(0, now - freeBefore)
            if current > freed + 10_000_000 {
                freed = current
                lastGrowth = Date()
            }
            lastCleanResult?.freed = freed
            // Done once most of the estimate came back, or nothing moved for 10 s after it started
            if freed >= expected * 9 / 10 || (freed > 0 && Date().timeIntervalSince(lastGrowth) > 10) { break }
        }
        guard !Task.isCancelled else { return }
        if let now = Self.availableBytes() {
            lastCleanResult?.freed = max(freed, now - freeBefore, 0)
        }
        lastCleanResult?.isMeasuring = false
        refreshFreeSpace()
    }

    /// Free bytes on the home volume, without purgeable space (so before/after compare real deletions).
    private static func availableBytes() -> Int64? {
        let values = try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: [.volumeAvailableCapacityKey])
        return values?.volumeAvailableCapacity.map(Int64.init)
    }
}
