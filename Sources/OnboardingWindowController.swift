import AppKit
import SwiftUI

@MainActor
final class OnboardingWindowController: NSWindowController, NSWindowDelegate {
    let model = OnboardingModel()
    private let onFinish: () -> Void

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 440),
                              styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Welcome to Robin"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        window.contentView = NSHostingView(rootView: OnboardingView(model: model) { [weak self] in
            self?.window?.orderOut(nil)
            self?.onFinish()
        })
        window.center()
    }

    required init?(coder: NSCoder) { fatalError("Use init(onFinish:)") }

    func show() {
        if window?.isVisible == true {
            NSApp.activate(ignoringOtherApps: true)
            window?.makeKeyAndOrderFront(nil)
            return
        }
        model.begin()
        window?.title = model.progress.isComplete ? "Robin Setup & Tour" : "Welcome to Robin"
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        Task { await model.refresh() }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        Task { await model.refresh() }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if !model.progress.isComplete {
            NSApp.terminate(nil)
            return false
        }
        return true
    }
}
