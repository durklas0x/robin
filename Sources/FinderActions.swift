import AppKit
import Combine

@MainActor
final class FinderActions: ObservableObject {
    @Published var path = ""
    @Published var message = ""
    var fileDialog: FileDialogSnapshot?
    private(set) var navigatingDialog = false

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
            guard FolderPath.isDirectory(supplied) else { throw ActionError.failed("Choose a folder for this action.") }
            path = supplied.path
            return supplied
        }
        if let dialog = fileDialog {
            guard let folder = dialog.folder else {
                throw ActionError.failed("Enter an absolute folder path first; this dialog does not expose its current folder.")
            }
            path = folder.path
            return folder
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
            alert.messageText = "Robin could not complete the action"
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

    @discardableResult
    func navigate(to input: String) async -> Bool {
        guard !navigatingDialog else { return false }
        var resolved: URL?
        perform {
            let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
            if fileDialog != nil && path.isEmpty && !trimmedInput.hasPrefix("/") && !trimmedInput.hasPrefix("~") && !trimmedInput.hasPrefix("file://") {
                throw ActionError.failed("Enter an absolute folder path, such as ~/Documents.")
            }
            let base = URL(fileURLWithPath: path.isEmpty ? NSHomeDirectory() : path, isDirectory: true)
            let destination = try FolderPath.resolve(input, relativeTo: base)
            guard FolderPath.isDirectory(destination) else {
                throw ActionError.failed("Enter the path of an existing folder.")
            }
            resolved = destination
        }
        guard let destination = resolved else { return false }
        if let dialog = fileDialog {
            navigatingDialog = true
            defer { navigatingDialog = false }
            NSRunningApplication(processIdentifier: dialog.processID)?.activate(options: [])
            let success = await Task.detached { FileDialogReader.navigate(to: destination, in: dialog) }.value
            if success { path = destination.path }
            else { perform { throw ActionError.failed("Could not navigate this file dialog. Use its Go to Folder command and try again.") } }
            return success
        }
        var navigated = false
        perform {
            _ = try script("""
            tell application "Finder"
                set destination to (POSIX file \(appleScriptQuote(destination.path)) as alias)
                if (count of Finder windows) is 0 then
                    make new Finder window to destination
                else
                    set target of front Finder window to destination
                end if
                activate
            end tell
            """)
            path = destination.path
            navigated = true
        }
        return navigated
    }

    func newFile(in supplied: URL? = nil) {
        let dialog = supplied == nil ? fileDialog : nil
        perform {
            let folder = try folder(supplied)
            guard let name = NewFileDialog(folder: folder).run() else { return }
            let url = try NewFileDestination.url(name: name, in: folder)
            // Never overwrite an existing file, after the filename prompt is confirmed.
            try Data().write(to: url, options: .withoutOverwriting)
            if let dialog {
                NSRunningApplication(processIdentifier: dialog.processID)?.activate(options: [])
            } else {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
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
