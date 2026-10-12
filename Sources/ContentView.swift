import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var actions: FinderActions
    // The legacy icon file contains the cream artwork, which contrasts with this window.
    private var aboutIcon: NSImage {
        guard let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
              let image = NSImage(contentsOf: url) else {
            return NSApplication.shared.applicationIconImage
        }
        return image
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(nsImage: aboutIcon)
                    .resizable()
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
                Text("Robin").font(.title.bold())
            }
            Text("Finder’s little sidekick.")
            Text("The location bar follows the active Finder window. Grant Finder Automation access when macOS asks.")
                .fixedSize(horizontal: false, vertical: true)
            Button("Finder Extension Settings…") {
                FinderExtensionSettings.open()
            }
            Text("Turn on Robin in the extension sheet, then click Done. macOS may label this sheet File Providers.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !actions.message.isEmpty { Text(actions.message).foregroundStyle(.red) }
        }.padding(24).frame(width: 440)
    }
}
