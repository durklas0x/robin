import SwiftUI

@main
struct PathletApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
        Settings { ContentView().environmentObject(delegate.actions) }
        MenuBarExtra("Pathlet", systemImage: "folder.badge.gearshape") {
            Button("Show Finder Bar") { delegate.bar.update() }
            Button("Copy Current Folder Path") { delegate.actions.copyPath() }
            Button("New File…") { delegate.actions.newFile() }
            Divider()
            Button("Open Terminal Here") { delegate.actions.openTerminal() }
            Button("Open in Editor…") { delegate.actions.openEditor() }
            Divider()
            Button("Finder Extension Settings…") { delegate.enableExtension() }
            SettingsLink { Text("About Pathlet…") }
            Button("Quit Pathlet") { NSApplication.shared.terminate(nil) }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let actions = FinderActions()
    lazy var bar = FinderBarController(actions: actions)
    func applicationDidFinishLaunching(_ notification: Notification) { bar.start() }
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { actions.handle(url) }
    }
    func enableExtension() {
        FinderExtensionSettings.open()
    }
}
