import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var actions: FinderActions
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Pathlet", systemImage: "folder.badge.gearshape").font(.title.bold())
            Text("Your folder actions, right beside Finder.")
            Text("The location bar follows the active Finder window. Grant Finder Automation access when macOS asks.")
                .fixedSize(horizontal: false, vertical: true)
            Button("Enable Finder right-click actions…") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences")!)
            }
            Text("In System Settings, enable Pathlet Finder Actions under Finder extensions. On recent macOS versions, look under General → Login Items & Extensions → Finder.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !actions.message.isEmpty { Text(actions.message).foregroundStyle(.red) }
        }.padding(24).frame(width: 440)
    }
}
