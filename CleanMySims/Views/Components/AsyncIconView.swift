import SwiftUI

/// Displays an app icon thumbnail for a cleanable item.
///
/// **Fully stateless** — no @State, no onAppear, no async, no callbacks.
/// Icons are pre-loaded during the scan phase (see `SimulatorManager`).
/// The view simply reads from `IconThumbnailCache` synchronously.
struct AsyncIconView: View {
    let itemPath: String
    let appIconPath: String?

    var body: some View {
        // Priority: app icon thumbnail > system icon for path
        let icon: NSImage? = {
            if let path = appIconPath {
                return IconThumbnailCache.shared.thumbnail(forKey: path)
            }
            return IconThumbnailCache.shared.thumbnail(forKey: itemPath)
        }()

        if let icon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
        } else {
            // Fallback (should rarely happen — icons are pre-loaded during scan)
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.gray.opacity(0.08))
                Image(systemName: "doc.fill")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
