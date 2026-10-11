import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var actions: FinderActions

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label("Pathlet", systemImage: "folder.badge.gearshape")
                .font(.largeTitle.bold())
            Text("A shorter path through Finder.").foregroundStyle(.secondary)
            GroupBox("Current Finder location") {
                HStack {
                    Text(actions.path.isEmpty ? "Refresh to read your Finder folder" : actions.path)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Refresh") { actions.refresh() }
                    Button("Copy") { actions.copyPath() }
                        .keyboardShortcut("c", modifiers: [.command, .shift])
                }.padding(8)
            }
            HStack {
                Button("New File…", systemImage: "doc.badge.plus") { actions.newFile() }
                Button("Terminal", systemImage: "terminal") { actions.openTerminal() }
                Button("Editor…", systemImage: "curlybraces") { actions.openEditor() }
            }
            Text("This starter provides folder actions and a selectable location bar. Finder right-click integration, a global shortcut, and mouse/trackpad navigation are next.")
                .font(.callout).foregroundStyle(.secondary)
            if !actions.message.isEmpty {
                Text(actions.message).font(.callout).textSelection(.enabled)
            }
        }
        .padding(28)
        .frame(minWidth: 620, minHeight: 300)
    }
}
