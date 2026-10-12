import AppKit
import SwiftUI

/// Created only by the About menu command, never by startup or action URLs.
@MainActor
final class SettingsWindowController: NSWindowController {
    init(actions: FinderActions) {
        let content = NSHostingView(rootView: ContentView().environmentObject(actions))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: content.fittingSize),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Robin Settings"
        window.isReleasedWhenClosed = false
        window.contentView = content
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError("Use init(actions:)") }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
