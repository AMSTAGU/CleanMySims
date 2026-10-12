import Foundation
import AppKit
import ImageIO

/// Thread-safe icon thumbnail cache.
///
/// Uses `NSCache` under the hood which is inherently thread-safe (no locks needed).
/// All thumbnail creation uses `CGImageSource` (Core Graphics) — fully thread-safe,
/// no AppKit/NSWorkspace calls from any thread.
nonisolated final class IconThumbnailCache: @unchecked Sendable {

    static let shared = IconThumbnailCache()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 500
    }

    // MARK: - Public API

    /// Returns a cached thumbnail, or `nil` if not yet loaded.
    func thumbnail(forKey key: String) -> NSImage? {
        cache.object(forKey: key as NSString)
    }

    /// Synchronously creates a 64px thumbnail from `path` and caches it.
    /// Safe to call from ANY thread. Uses only Core Graphics APIs.
    func preloadThumbnail(forKey key: String, fromPath path: String) {
        // Already cached → skip
        if cache.object(forKey: key as NSString) != nil { return }

        guard let image = Self.makeThumbnail(atPath: path) else { return }
        cache.setObject(image, forKey: key as NSString)
    }

    // MARK: - Private

    /// Creates a small thumbnail using ImageIO. Fully thread-safe.
    /// Returns nil for invalid/unreadable/corrupted files.
    private static func makeThumbnail(atPath path: String) -> NSImage? {
        let url = URL(fileURLWithPath: path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 64
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: 32, height: 32))
    }

    /// Pre-loads the system icon for a file/folder path using NSWorkspace.
    /// Call from the scan's background thread — the icon is cached for later
    /// synchronous reads by the view layer.
    func preloadSystemIcon(forPath path: String) {
        let key = path as NSString
        if cache.object(forKey: key) != nil { return }

        let icon = NSWorkspace.shared.icon(forFile: path)
        icon.size = NSSize(width: 32, height: 32)
        cache.setObject(icon, forKey: key)
    }
}
