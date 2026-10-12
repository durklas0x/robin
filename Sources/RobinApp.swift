import SwiftUI
import Carbon

@main
struct RobinApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        MenuBarExtra {
            Button("Setup & Tour…") { delegate.onboarding.show() }
            Button("Finder Extension Settings…") { delegate.enableExtension() }
            FileDialogMenu(support: delegate.fileDialogs)
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
    let fileDialogs = FileDialogSupport()
    lazy var bar = FinderBarController(actions: actions, fileDialogs: fileDialogs)
    lazy var settings = SettingsWindowController(actions: actions)
    lazy var onboarding = OnboardingWindowController { [weak self] in self?.startUtility() }
    private var pendingActions: [URL] = []
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(self,
            andSelector: #selector(receiveURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        if onboarding.model.progress.isComplete { startUtility() }
        else { onboarding.show() }
    }

    private func startUtility() {
        bar.start()
        let requests = pendingActions
        pendingActions.removeAll()
        for url in requests { actions.handle(url) }
    }
    @objc private func receiveURL(_ event: NSAppleEventDescriptor, withReplyEvent reply: NSAppleEventDescriptor) {
        guard let value = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))?.stringValue,
              let url = URL(string: value) else { return }
        // Deliver after startup and outside the Apple Event callback's stack.
        Task { @MainActor in
            if self.onboarding.model.progress.isComplete { self.actions.handle(url) }
            else {
                self.pendingActions.append(url)
                self.onboarding.show()
            }
        }
    }
    func enableExtension() {
        FinderExtensionSettings.open()
    }
}

private struct FileDialogMenu: View {
    @ObservedObject var support: FileDialogSupport

    var body: some View {
        Toggle("Show in Open & Save Dialogs", isOn: Binding(get: { support.enabled }, set: { support.setEnabled($0) }))
        if support.enabled && !support.accessibilityAllowed {
            Button("Allow Accessibility for File Dialogs…") { support.openSettings() }
        }
    }
}
