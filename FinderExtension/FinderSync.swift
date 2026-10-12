import Cocoa
import FinderSync
import OSLog

final class FinderSync: FIFinderSync {
    private var requests = MenuRequestStore()
    override init() {
        super.init()
        // Register local filesystem locations, including mounted external volumes.
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let controller = FIFinderSyncController.default()
        guard let target = controller.targetedURL() else { return nil }
        let candidate: URL
        if menuKind == .contextualMenuForItems,
           let selected = controller.selectedItemURLs(), selected.count == 1,
           (selected[0].hasDirectoryPath || (try? selected[0].resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true) {
            candidate = selected[0]
        } else {
            candidate = target
        }
        let isDirectory = menuKind == .contextualMenuForContainer || candidate.hasDirectoryPath ||
            (try? candidate.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        let folder = isDirectory ? candidate : candidate.deletingLastPathComponent()
        let menu = NSMenu(title: "Pathlet")
        for (title, action) in [("New File", ActionRequest.Action.newFile),
                                ("Copy Folder Path", .copy),
                                ("Open Terminal Here", .terminal),
                                ("Open in Editor", .editor)] {
            let item = NSMenuItem(title: title, action: #selector(runAction(_:)), keyEquivalent: "")
            item.target = self
            // Capture context now; do not ask the host to re-read another Finder window.
            item.tag = requests.register(ActionRequest(action: action, folder: folder))
            menu.addItem(item)
        }
        return menu
    }

    @objc private func runAction(_ sender: NSMenuItem) {
        guard let request = requests.request(for: sender.tag) else { return }
        // Use this extension's containing app, not Launch Services' preferred copy.
        let host = Bundle.main.bundleURL.deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.open([request.url], withApplicationAt: host,
                                configuration: configuration) { _, error in
            if let error {
                Logger(subsystem: "com.durklas0x.Pathlet", category: "handoff")
                    .error("Could not open the containing app: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
