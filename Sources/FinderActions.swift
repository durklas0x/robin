import AppKit
import Combine

@MainActor
final class FinderActions: ObservableObject {
    @Published var path = ""
    @Published var message = ""

    private func script(_ source: String) throws -> NSAppleEventDescriptor {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            throw ActionError.failed("Could not compile the Finder action.")
        }
        let result = script.executeAndReturnError(&error)
        if let error {
            throw ActionError.failed(error[NSAppleScript.errorMessage] as? String ?? "Automation failed.")
        }
        return result
    }

    private func folder(_ supplied: URL? = nil) throws -> URL {
        if let supplied {
            let values = try supplied.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else { throw ActionError.failed("Choose a folder for this action.") }
            path = supplied.path
            return supplied
        }
        let result = try script("""
        tell application "Finder"
            if (count of Finder windows) is 0 then
                error "Open a Finder window first."
            end if
            return POSIX path of (target of front Finder window as alias)
        end tell
        """)
        guard let value = result.stringValue else { throw ActionError.failed("Finder did not return a folder.") }
        let url = URL(fileURLWithPath: value, isDirectory: true)
        path = url.path
        return url
    }

    private func perform(_ action: () throws -> Void) {
        do { try action(); message = "" }
        catch {
            message = error.localizedDescription
            let alert = NSAlert()
            alert.messageText = "Pathlet could not complete the action"
            alert.informativeText = message
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }

    func refresh() { perform { _ = try folder() } }

    @discardableResult
    func copyPath(in supplied: URL? = nil) -> Bool {
        var copied = false
        perform {
            let folder = try folder(supplied)
            NSPasteboard.general.clearContents()
            copied = NSPasteboard.general.setString(folder.path, forType: .string)
        }
        return copied
    }

    func newFile(in supplied: URL? = nil) {
        perform {
            let folder = try folder(supplied)
            let prompt = NSAlert()
            prompt.messageText = "New File"
            prompt.informativeText = "Create an empty file in:\n" + folder.path
            prompt.addButton(withTitle: "Create")
            prompt.addButton(withTitle: "Cancel")
            let nameField = NSTextField(string: "Untitled.txt")
            nameField.frame = NSRect(x: 0, y: 0, width: 340, height: 24)
            nameField.setAccessibilityLabel("File name")
            prompt.accessoryView = nameField
            prompt.window.initialFirstResponder = nameField
            NSApp.activate(ignoringOtherApps: true)
            guard prompt.runModal() == .alertFirstButtonReturn else { return }
            let url = try NewFileDestination.url(name: nameField.stringValue, in: folder)
            // Never overwrite an existing file, after the filename prompt is confirmed.
            try Data().write(to: url, options: .withoutOverwriting)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    func openTerminal(in supplied: URL? = nil) {
        perform {
            let folder = try folder(supplied)
            let command = "cd -- " + shellQuote(folder.path)
            _ = try script("""
            tell application "Terminal"
                do script \(appleScriptQuote(command))
                activate
            end tell
            """)
        }
    }

    func openEditor(in supplied: URL? = nil) {
        perform {
            let folder = try folder(supplied)
            let panel = NSOpenPanel()
            panel.directoryURL = URL(fileURLWithPath: "/Applications")
            panel.allowedContentTypes = [.applicationBundle]
            panel.title = "Choose an editor application"
            NSApp.activate(ignoringOtherApps: true)
            guard panel.runModal() == .OK, let editor = panel.url else { return }
            NSWorkspace.shared.open([folder], withApplicationAt: editor,
                                    configuration: NSWorkspace.OpenConfiguration()) { _, error in
                if let error {
                    Task { @MainActor in self.message = error.localizedDescription }
                }
            }
        }
    }

    func handle(_ url: URL) {
        guard let request = ActionRequest(url: url) else { return }
        switch request.action {
        case .copy: copyPath(in: request.folder)
        case .newFile: newFile(in: request.folder)
        case .terminal: openTerminal(in: request.folder)
        case .editor: openEditor(in: request.folder)
        }
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }

    private func appleScriptQuote(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }

    private enum ActionError: LocalizedError {
        case failed(String)
        var errorDescription: String? {
            if case let .failed(message) = self { return message }
            return nil
        }
    }
}
