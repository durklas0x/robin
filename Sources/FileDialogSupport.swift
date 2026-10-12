import AppKit
import ApplicationServices
import Combine

@MainActor
final class FileDialogSupport: ObservableObject {
    @Published var enabled: Bool {
        didSet { defaults.set(enabled, forKey: "fileDialogs.enabled") }
    }
    @Published private(set) var accessibilityAllowed = AXIsProcessTrusted()
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        enabled = defaults.bool(forKey: "fileDialogs.enabled")
    }

    func refreshPermission() { accessibilityAllowed = AXIsProcessTrusted() }

    func setEnabled(_ value: Bool) {
        enabled = value
        refreshPermission()
        if value && !accessibilityAllowed { openSettings() }
    }

    func openSettings() {
        // This is called only after the user opts in or chooses Allow Accessibility.
        // Register this running copy with TCC before opening the permissions pane.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        accessibilityAllowed = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}

/// AX objects are only messaged by the background reader; immutable metadata is shared with the UI.
struct FileDialogSnapshot: @unchecked Sendable {
    let element: AXUIElement
    let processID: pid_t
    let bounds: CGRect
    let folder: URL?
    let folderName: String
}

struct FileDialogReader {
    static func snapshot(processID: pid_t) -> FileDialogSnapshot? {
        guard AXIsProcessTrusted() else { return nil }
        let app = AXUIElementCreateApplication(processID)
        AXUIElementSetMessagingTimeout(app, 0.15)
        guard let rawWindow = attribute(app, kAXFocusedWindowAttribute),
              CFGetTypeID(rawWindow) == AXUIElementGetTypeID() else { return nil }
        let window = rawWindow as! AXUIElement
        // Only inspect native file panels and their sheets, never an application's document content.
        let candidates = modalChildren(of: window) + [window]
        guard let dialog = candidates.first(where: { element in
            FileDialogIdentity.isPanel(identifier: string(element, kAXIdentifierAttribute))
        }), let bounds = frame(dialog), bounds.width > 0, bounds.height > 0 else { return nil }
        let elements = descendants(of: dialog)
        // Don't compete with Go to Folder, alerts, or confirmation sheets already inside the panel.
        guard modalChildren(of: dialog).isEmpty else { return nil }
        let folderName = elements.first(where: { string($0, kAXIdentifierAttribute) == "where popup" })
            .map { string($0, kAXValueAttribute) } ?? ""
        let searching = elements.contains { string($0, kAXSubroleAttribute) == "AXSearchField" && !string($0, kAXValueAttribute).isEmpty }
        let browserItems = elements.filter { FileDialogIdentity.isBrowser(identifier: string($0, kAXIdentifierAttribute)) }
            .flatMap { descendants(of: $0, depthFirst: true) }
        let urls = browserItems.compactMap { element -> URL? in
            guard let url = attribute(element, kAXURLAttribute) as? URL, url.isFileURL else { return nil }
            return url.deletingLastPathComponent()
        }
        let folder = searching ? nil : FileDialogIdentity.folder(from: urls, named: folderName)
        return FileDialogSnapshot(element: dialog, processID: processID, bounds: bounds,
                                  folder: folder, folderName: folderName)
    }

    static func navigate(to folder: URL, in snapshot: FileDialogSnapshot) -> Bool {
        guard let current = self.snapshot(processID: snapshot.processID),
              CFEqual(current.element, snapshot.element),
              NSWorkspace.shared.frontmostApplication?.processIdentifier == snapshot.processID else { return false }
        sendKey(5, flags: [.maskCommand, .maskShift], to: snapshot.processID) // Native Go to Folder.
        let deadline = Date().addingTimeInterval(1.5)
        while Date() < deadline {
            // Search only children of the captured panel, never another window's sheet.
            let sheets = modalChildren(of: snapshot.element)
            if let sheet = sheets.first(where: { string($0, kAXIdentifierAttribute) == "GoToWindow" }),
               isOwned(sheet, by: snapshot.element),
               let field = descendants(of: sheet).first(where: { string($0, kAXIdentifierAttribute) == "PathTextField" }) {
                guard NSWorkspace.shared.frontmostApplication?.processIdentifier == snapshot.processID,
                      attribute(field, kAXFocusedAttribute) as? Bool == true,
                      AXUIElementSetAttributeValue(field, kAXValueAttribute as CFString, folder.path as CFString) == .success,
                      isOwned(field, by: sheet) else { return false }
                // Confirm the path field directly. Never send Return to the app's Open/Save button.
                return AXUIElementPerformAction(field, "AXConfirm" as CFString) == .success
            }
            if !sheets.isEmpty { return false }
            Thread.sleep(forTimeInterval: 0.04)
        }
        return false
    }

    private static func sendKey(_ code: CGKeyCode, flags: CGEventFlags, to processID: pid_t) {
        let source = CGEventSource(stateID: .privateState)
        for down in [true, false] {
            let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down)
            event?.flags = flags
            event?.postToPid(processID)
        }
    }

    private static func attribute(_ element: AXUIElement, _ key: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, key as CFString, &value) == .success else { return nil }
        return value
    }

    private static func string(_ element: AXUIElement, _ key: String) -> String {
        attribute(element, key) as? String ?? ""
    }

    private static func descendants(of root: AXUIElement, depthFirst: Bool = false) -> [AXUIElement] {
        var result: [AXUIElement] = []
        var queue = attribute(root, kAXChildrenAttribute) as? [AXUIElement] ?? []
        var offset = 0
        if depthFirst { queue.reverse() }
        while (depthFirst ? !queue.isEmpty : offset < queue.count), result.count < 300 {
            let element: AXUIElement
            if depthFirst { element = queue.removeLast() }
            else { element = queue[offset]; offset += 1 }
            result.append(element)
            let children = (attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []) +
                (attribute(element, "AXSheets") as? [AXUIElement] ?? [])
            let unseen = children.prefix(300).filter { child in
                !result.contains(where: { CFEqual($0, child) }) && !queue.contains(where: { CFEqual($0, child) })
            }
            queue.append(contentsOf: depthFirst ? unseen.reversed() : unseen)
        }
        return result
    }

    private static func modalChildren(of element: AXUIElement) -> [AXUIElement] {
        let sheets = attribute(element, "AXSheets") as? [AXUIElement] ?? []
        let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
        return sheets + children.filter {
            string($0, kAXRoleAttribute) == kAXSheetRole ||
            string($0, kAXSubroleAttribute) == kAXDialogSubrole
        }
    }

    private static func isOwned(_ element: AXUIElement, by owner: AXUIElement) -> Bool {
        var current: CFTypeRef? = element
        for _ in 0..<12 {
            guard let value = current, CFGetTypeID(value) == AXUIElementGetTypeID() else { return false }
            let node = value as! AXUIElement
            if CFEqual(node, owner) { return true }
            current = attribute(node, kAXParentAttribute)
        }
        return false
    }

    private static func frame(_ element: AXUIElement) -> CGRect? {
        guard let rawPosition = attribute(element, kAXPositionAttribute),
              let rawSize = attribute(element, kAXSizeAttribute),
              CFGetTypeID(rawPosition) == AXValueGetTypeID(), CFGetTypeID(rawSize) == AXValueGetTypeID() else { return nil }
        let position = rawPosition as! AXValue
        let size = rawSize as! AXValue
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(position, .cgPoint, &point), AXValueGetValue(size, .cgSize, &dimensions) else { return nil }
        return CGRect(origin: point, size: dimensions)
    }
}
