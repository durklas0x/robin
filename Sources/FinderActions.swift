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

    private func folder() throws -> URL {
        let result = try script("""
        tell application "Finder"
            if (count of Finder windows) is 0 then
                error "Open a Finder window first."
            end if
            return POSIX path of (target of front Finder window as alias)
        end tell
        """)
        guard let value = result.stringValue else { throw ActionError.failed("Finder did not return a folder.") }
        path = value
        return URL(fileURLWithPath: value, isDirectory: true)
    }

    private func perform(_ action: () throws -> Void) {
        do { try action(); message = "" }
        catch { message = error.localizedDescription }
    }

    func refresh() { perform { _ = try folder() } }

    func copyPath() {
        perform {
            let folder = try folder()
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(folder.path, forType: .string)
        }
    }

    func newFile() {
        perform {
            let folder = try folder()
            let panel = NSSavePanel()
            panel.directoryURL = folder
            panel.nameFieldStringValue = "Untitled.txt"
            panel.title = "New File"
            panel.prompt = "Create"
            NSApp.activate(ignoringOtherApps: true)
            guard panel.runModal() == .OK, let url = panel.url else { return }
            // Never overwrite an existing file, even if the save panel permits replacement.
            try Data().write(to: url, options: .withoutOverwriting)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    func openTerminal() {
        perform {
            let folder = try folder()
            let command = "cd -- " + shellQuote(folder.path)
            _ = try script("""
            tell application "Terminal"
                do script \(appleScriptQuote(command))
                activate
            end tell
            """)
        }
    }

    func openEditor() {
        perform {
            let folder = try folder()
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
