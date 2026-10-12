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
        var size: Int64
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
    private(set) var lastScanDate: Date?
    private(set) var freeSpace: Int64?

    private(set) var isCleaning = false
    private(set) var cleaningDone = 0
    private(set) var cleaningTotal = 0

    @ObservationIgnored private var scanTask: Task<Void, Never>?

    var totalSize: Int64 {
        categoryStats.values.reduce(0) { $0 + $1.size }
    }

    var safeItems: [CleanableItem] {
        items.filter { $0.type.isSafeToDelete }
    }

    var safeSize: Int64 {
        categoryStats.filter { $0.key.isSafeToDelete }.values.reduce(0) { $0 + $1.size }
    }

    /// Size to show for a category: the final total once it is scanned, the running count before that.
    func size(of type: CleanableItemType) -> Int64 {
        categoryStats[type]?.size ?? progress.found[type] ?? 0
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
        case .finished(let type, let newItems):
            progress.scanning.remove(type)
            progress.done.insert(type)
            let size = newItems.reduce(0) { $0 + $1.size }
            progress.found[type] = size
            if !newItems.isEmpty {
                items.append(contentsOf: newItems)
                categoryStats[type] = CategoryStats(count: newItems.count, size: size)
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
    func clean(_ itemsToClean: [CleanableItem]) {
        guard !itemsToClean.isEmpty, !isCleaning else { return }
        isCleaning = true
        cleaningDone = 0
        cleaningTotal = itemsToClean.count

        Task {
            for item in itemsToClean {
                await Task.detached(priority: .userInitiated) {
                    DiskScanner.remove(item)
                }.value
                forget(item)
                cleaningDone += 1
            }
            isCleaning = false
            refreshFreeSpace()
        }
    }

    private func forget(_ item: CleanableItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id && $0.type == item.type }) else { return }
        items.remove(at: index)
        guard var stats = categoryStats[item.type] else { return }
        stats.count -= 1
        stats.size -= item.size
        categoryStats[item.type] = stats.count > 0 ? stats : nil
    }
}
