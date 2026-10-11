import AppKit

/// A small native utility panel: no app icon or alert-style explanatory block.
@MainActor
final class NewFileDialog: NSWindowController, NSWindowDelegate, NSTextFieldDelegate {
    private let folder: URL
    private let nameField = NSTextField(string: "Untitled.txt")
    private let createButton = NSButton(title: "Create", target: nil, action: nil)
    private var accepted = false

    init(folder: URL) {
        self.folder = folder
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 340, height: 126),
                            styleMask: [.titled, .closable, .utilityWindow],
                            backing: .buffered, defer: false)
        panel.title = "New File"
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        super.init(window: panel)
        panel.delegate = self
        configure(panel)
    }

    required init?(coder: NSCoder) { fatalError("Use init(folder:)") }

    func run() -> String? {
        guard let window else { return nil }
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.makeFirstResponder(nameField)
        // Select the base name while keeping the extension ready to use.
        if let editor = nameField.currentEditor() {
            let name = nameField.stringValue as NSString
            let base = name.deletingPathExtension as NSString
            editor.selectedRange = NSRange(location: 0, length: base.length)
        }
        NSApp.runModal(for: window)
        window.orderOut(nil)
        return accepted ? nameField.stringValue : nil
    }

    private func configure(_ panel: NSPanel) {
        guard let content = panel.contentView else { return }
        let destination = NSTextField(labelWithString: "In \(folder.lastPathComponent.isEmpty ? folder.path : folder.lastPathComponent)")
        destination.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        destination.textColor = .secondaryLabelColor
        destination.lineBreakMode = .byTruncatingMiddle
        destination.toolTip = folder.path
        destination.setAccessibilityLabel("Destination: " + folder.path)

        nameField.bezelStyle = .roundedBezel
        nameField.font = .systemFont(ofSize: NSFont.systemFontSize)
        nameField.setAccessibilityLabel("File name")
        nameField.delegate = self

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        createButton.target = self
        createButton.action = #selector(create)
        createButton.bezelStyle = .rounded
        createButton.keyEquivalent = "\r"
        panel.defaultButtonCell = createButton.cell as? NSButtonCell
        panel.initialFirstResponder = nameField

        for view in [destination, nameField, cancelButton, createButton] {
            view.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(view)
        }
        NSLayoutConstraint.activate([
            destination.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),
            destination.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            destination.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            nameField.topAnchor.constraint(equalTo: destination.bottomAnchor, constant: 8),
            nameField.leadingAnchor.constraint(equalTo: destination.leadingAnchor),
            nameField.trailingAnchor.constraint(equalTo: destination.trailingAnchor),
            nameField.heightAnchor.constraint(equalToConstant: 24),
            createButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            createButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
            createButton.widthAnchor.constraint(equalToConstant: 80),
            cancelButton.trailingAnchor.constraint(equalTo: createButton.leadingAnchor, constant: -8),
            cancelButton.centerYAnchor.constraint(equalTo: createButton.centerYAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 80)
        ])
    }

    func controlTextDidChange(_ notification: Notification) {
        createButton.isEnabled = (try? NewFileDestination.url(name: nameField.stringValue, in: folder)) != nil
    }

    @objc private func create() {
        guard createButton.isEnabled else { return }
        accepted = true
        NSApp.stopModal()
    }

    @objc private func cancel() { NSApp.stopModal() }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        NSApp.stopModal()
        return true
    }
}
