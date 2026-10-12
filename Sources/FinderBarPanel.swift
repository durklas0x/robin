import AppKit

final class FinderBarPanel: NSPanel {
    override var contentView: NSView? {
        didSet {
            // AppKit otherwise selects the first text field when this panel becomes key.
            initialFirstResponder = contentView
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func resignKey() {
        // The nonactivating panel can retain an inactive field-editor selection.
        if let editor = firstResponder as? NSText {
            editor.selectedRange = NSRange(location: 0, length: 0)
        }
        makeFirstResponder(nil)
        super.resignKey()
        NotificationCenter.default.post(name: .finderBarDidEndEditing, object: self)
    }
}

extension Notification.Name {
    static let finderBarDidEndEditing = Notification.Name("Robin.FinderBarDidEndEditing")
}

