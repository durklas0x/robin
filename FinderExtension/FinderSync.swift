import Cocoa
import FinderSync

final class FinderSync: FIFinderSync {
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
        for (title, action) in [("New File…", ActionRequest.Action.newFile),
                                ("Copy Folder Path", .copy),
                                ("Open Terminal Here", .terminal),
                                ("Open in Editor…", .editor)] {
            let item = NSMenuItem(title: title, action: #selector(runAction(_:)), keyEquivalent: "")
            item.target = self
            // Capture context now; do not ask the host to re-read another Finder window.
            item.representedObject = ActionRequest(action: action, folder: folder).url
            menu.addItem(item)
        }
        return menu
    }

    @objc private func runAction(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSWorkspace.shared.open(url)
    }
}
