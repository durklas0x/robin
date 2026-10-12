import AppKit
import SwiftUI

/// Uses AppKit's completion list, including its keyboard navigation and dismissal.
struct FolderPathField: NSViewRepresentable {
    @Binding var text: String
    @Binding var editing: Bool
    var base: URL
    var onSubmit: () -> Void
    var onCancel: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSTextField {
        let field = FolderTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.font = .systemFont(ofSize: 12)
        field.focusRingType = .none
        field.placeholderString = "Folder path"
        field.setAccessibilityLabel("Folder path")
        field.toolTip = "Edit path · Tab to complete folders · Return to open · Escape to cancel"
        field.delegate = context.coordinator
        field.onFocus = { [weak coordinator = context.coordinator] field in
            coordinator?.beginEditing(field)
        }
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text { field.stringValue = text }
        let coordinator = context.coordinator
        let ending = coordinator.renderedEditing && !editing
        coordinator.renderedEditing = editing
        if ending {
            // AppKit publishes its end-editing callback; let the SwiftUI update finish first.
            DispatchQueue.main.async { [weak field, weak coordinator] in
                guard coordinator?.parent.editing == false else { return }
                field?.window?.makeFirstResponder(nil)
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: FolderPathField
        var renderedEditing = false
        init(_ parent: FolderPathField) { self.parent = parent }

        func controlTextDidBeginEditing(_ notification: Notification) {
            if let field = notification.object as? NSTextField { beginEditing(field) }
        }

        func beginEditing(_ field: NSTextField) {
            if !parent.editing { parent.editing = true }
            if let editor = field.currentEditor() as? NSTextView {
                editor.isAutomaticTextCompletionEnabled = false
                editor.isAutomaticQuoteSubstitutionEnabled = false
                editor.isAutomaticDashSubstitutionEnabled = false
                editor.isAutomaticSpellingCorrectionEnabled = false
            }
        }

        func controlTextDidChange(_ notification: Notification) {
            if let field = notification.object as? NSTextField { parent.text = field.stringValue }
        }

        func controlTextDidEndEditing(_ notification: Notification) {
            if parent.editing { parent.editing = false }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy command: Selector) -> Bool {
            switch command {
            case #selector(NSResponder.insertTab(_:)):
                textView.complete(nil)
                return true
            case #selector(NSResponder.insertNewline(_:)):
                parent.text = textView.string
                parent.onSubmit()
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onCancel()
                return true
            default: return false
            }
        }

        private var selectedCompletion: String?

        func completeFolders(in field: NSTextField, editor: NSTextView) {
            let range = editor.rangeForUserCompletion
            let input = (editor.string as NSString).substring(with: range)
            let candidates = FolderCompletion.candidates(for: input, relativeTo: parent.base)
            guard !candidates.isEmpty else { NSSound.beep(); return }
            if candidates.count == 1 {
                applyCompletion(candidates[0], in: field, range: range)
                return
            }
            let panel = field.window as? FinderBarPanel
            panel?.beginCompletionTracking()
            defer { panel?.endCompletionTracking() }
            selectedCompletion = nil
            let menu = NSMenu(title: "Folder completions")
            menu.font = .systemFont(ofSize: 12)
            menu.autoenablesItems = false
            for candidate in candidates {
                let item = NSMenuItem(title: (candidate as NSString).lastPathComponent,
                                      action: #selector(selectCompletion(_:)), keyEquivalent: "")
                item.image = NSImage(named: NSImage.folderName)
                item.target = self
                item.representedObject = candidate
                menu.addItem(item)
            }
            menu.popUp(positioning: nil,
                       at: NSPoint(x: 0, y: field.isFlipped ? field.bounds.maxY : field.bounds.minY), in: field)
            if let selectedCompletion { applyCompletion(selectedCompletion, in: field, range: range) }
        }

        @objc private func selectCompletion(_ item: NSMenuItem) {
            selectedCompletion = item.representedObject as? String
        }

        func applyCompletion(_ candidate: String, in field: NSTextField, range: NSRange) {
            field.window?.makeKey()
            field.window?.makeFirstResponder(field)
            guard let editor = field.currentEditor() as? NSTextView else { return }
            editor.insertText(candidate, replacementRange: range)
            parent.text = editor.string
            parent.editing = true
        }

        func control(_ control: NSControl, textView: NSTextView, completions words: [String],
                     forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>) -> [String] {
            index.pointee = 0
            let input = (textView.string as NSString).substring(with: charRange)
            return FolderCompletion.candidates(for: input, relativeTo: parent.base)
        }
    }
}

final class FolderPathEditor: NSTextView {
    weak var completionControl: NSTextField?

    override func complete(_ sender: Any?) {
        guard let field = completionControl, let coordinator = field.delegate as? FolderPathField.Coordinator else {
            super.complete(sender)
            return
        }
        coordinator.completeFolders(in: field, editor: self)
    }

    override var rangeForUserCompletion: NSRange {
        // Complete the whole path, including slashes, spaces, and Unicode folder names.
        NSRange(location: 0, length: NSMaxRange(selectedRange()))
    }
}

private final class FolderTextField: NSTextField {
    var onFocus: ((NSTextField) -> Void)?

    override func becomeFirstResponder() -> Bool {
        let accepted = super.becomeFirstResponder()
        if accepted { onFocus?(self) }
        return accepted
    }
}
