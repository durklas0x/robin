import SwiftUI
import Carbon

@main
struct RobinApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        MenuBarExtra {
            Button("Finder Extension Settings…") { delegate.enableExtension() }
            Button("About Robin…") { delegate.settings.show() }
            Button("Quit Robin") { NSApplication.shared.terminate(nil) }
        } label: {
            Image(nsImage: MenuBarIcon.image)
                .accessibilityLabel("Robin")
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let actions = FinderActions()
    lazy var bar = FinderBarController(actions: actions)
    lazy var settings = SettingsWindowController(actions: actions)
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(self,
            andSelector: #selector(receiveURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }
    func applicationDidFinishLaunching(_ notification: Notification) { bar.start() }
    @objc private func receiveURL(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard let value = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: value) else { return }
        // Deliver after startup and outside the Apple Event callback's stack.
        Task { @MainActor in self.actions.handle(url) }
    }
    func enableExtension() {
        FinderExtensionSettings.open()
    }
}
