import Foundation

struct FileDialogIdentity {
    static func isPanel(identifier: String) -> Bool {
        ["open-panel", "save-panel"].contains(identifier)
    }

    static func isBrowser(identifier: String) -> Bool {
        ["IconView", "ListView", "ColumnView"].contains(identifier)
    }

    static func folder(from itemParents: [URL], named name: String) -> URL? {
        // Sidebar/search items can belong to other folders. Require one unambiguous parent
        // matching the dialog's current folder, rather than falling back to Finder.
        let matching = itemParents.filter {
            $0.lastPathComponent == name || (try? $0.resourceValues(forKeys: [.localizedNameKey]).localizedName) == name
        }
        let paths = Set(matching.map { $0.standardizedFileURL.path })
        guard paths.count == 1, let path = paths.first else { return nil }
        return URL(fileURLWithPath: path, isDirectory: true)
    }
}
