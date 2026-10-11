import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var actions: FinderActions
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Pathlet", systemImage: "folder.badge.gearshape").font(.title.bold())
            Text("Your folder actions, right beside Finder.")
            Text("The location bar follows the active Finder window. Grant Finder Automation access when macOS asks.")
                .fixedSize(horizontal: false, vertical: true)
            Button("Finder Extension Settings…") {
                FinderExtensionSettings.open()
            }
            Text("Turn on Pathlet in the extension sheet, then click Done. macOS may label this sheet File Providers.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !actions.message.isEmpty { Text(actions.message).foregroundStyle(.red) }
        }.padding(24).frame(width: 440)
    }
}
