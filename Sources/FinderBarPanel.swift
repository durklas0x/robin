import AppKit

final class FinderBarPanel: NSPanel, NSWindowDelegate {
    private lazy var pathEditor: FolderPathEditor = {
        let editor = FolderPathEditor()
        editor.isFieldEditor = true
        return editor
    }()

    private var trackingCompletions = false

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask,
                  backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        delegate = self
    }

    func windowWillReturnFieldEditor(_ sender: NSWindow, to client: Any?) -> Any? {
        guard let field = client as? NSTextField else { return nil }
        pathEditor.completionControl = field
        return pathEditor
    }

    override var contentView: NSView? {
        didSet {
            // AppKit otherwise selects the first text field when this panel becomes key.
            initialFirstResponder = contentView
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func resignKey() {
        super.resignKey()
        endEditingIfNeeded()
    }

    func beginCompletionTracking() { trackingCompletions = true }

    func endCompletionTracking() {
        trackingCompletions = false
        endEditingIfNeeded()
    }

    private func endEditingIfNeeded() {
        // A native completion menu can temporarily take focus during a mouse selection.
        // Finish the menu action before deciding whether editing really ended.
        DispatchQueue.main.async { [weak self] in
            guard let self, !isKeyWindow, !trackingCompletions else { return }
            if let editor = firstResponder as? NSText {
                editor.selectedRange = NSRange(location: 0, length: 0)
            }
            makeFirstResponder(nil)
            NotificationCenter.default.post(name: .finderBarDidEndEditing, object: self)
        }
    }

}

extension Notification.Name {
    static let finderBarDidEndEditing = Notification.Name("Robin.FinderBarDidEndEditing")
}

