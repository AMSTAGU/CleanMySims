
import SwiftUI

struct AsyncIconView: View {
    let itemPath: String
    let appIconPath: String?
    
    @State private var image: NSImage?
    
    // Simple memory cache
    private static var iconCache = NSCache<NSString, NSImage>()
    
    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
            } else {
                // Placeholder while loading
                Color.gray.opacity(0.1)
            }
        }
        .task {
            await loadIcon()
        }
    }
    
    private func loadIcon() async {
        // Check cache first
        let cacheKey = (appIconPath ?? itemPath) as NSString
        if let cached = AsyncIconView.iconCache.object(forKey: cacheKey) {
            self.image = cached
            return
        }
        
        // Load in background
        let loadedImage = await Task.detached(priority: .userInitiated) { () -> NSImage in
            if let iconPath = appIconPath,
               (iconPath.lowercased().hasSuffix(".png") || iconPath.lowercased().hasSuffix(".icns")),
               let img = NSImage(contentsOfFile: iconPath) {
                return img
            } else {
                return NSWorkspace.shared.icon(forFile: itemPath)
            }
        }.value
        
        // Cache and update
        AsyncIconView.iconCache.setObject(loadedImage, forKey: cacheKey)
        self.image = loadedImage
    }
}
