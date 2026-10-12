import AppKit

@MainActor
enum AppArtwork {
    // The cream artwork in the fallback icon remains legible inside dark windows.
    static var icon: NSImage {
        guard let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
              let image = NSImage(contentsOf: url) else {
            return NSApplication.shared.applicationIconImage
        }
        return image
    }
}
