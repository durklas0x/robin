import SwiftUI

@main
struct PathletApp: App {
    @StateObject private var actions = FinderActions()

    var body: some Scene {
        WindowGroup("Pathlet") {
            ContentView().environmentObject(actions)
        }
        MenuBarExtra("Pathlet", systemImage: "folder.badge.gearshape") {
            Button("Copy Current Folder Path") { actions.copyPath() }
            Button("New File…") { actions.newFile() }
            Divider()
            Button("Open Terminal Here") { actions.openTerminal() }
            Button("Open in Editor…") { actions.openEditor() }
            Divider()
            Button("Quit Pathlet") { NSApplication.shared.terminate(nil) }
        }
    }
}
