import Foundation
import FinderSync

enum FinderExtensionStatus {
    enum Status: Equatable, Sendable {
        case checking, enabled, disabled, registrationPending, anotherCopySelected, unavailable
    }

    @MainActor
    static func check(registerCurrentCopy: Bool = false) async -> Status {
        let apiEnabled = FIFinderSyncController.isExtensionEnabled
        guard let directory = Bundle.main.builtInPlugInsURL else { return .unavailable }
        let extensionURL = directory.appendingPathComponent("RobinFinder.appex")
        guard let bundle = Bundle(url: extensionURL), let identifier = bundle.bundleIdentifier,
              let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else { return .unavailable }
        return await Task.detached {
            refresh(apiEnabled: apiEnabled, extensionURL: extensionURL, identifier: identifier,
                    version: version, registerCurrentCopy: registerCurrentCopy, run: runCommand)
        }.value
    }

    /// One seam for update registration and inspection; never changes the user's election.
    static func refresh(apiEnabled: Bool, extensionURL: URL, identifier: String, version: String,
                        registerCurrentCopy: Bool, run: ([String]) -> String?) -> Status {
        let query = ["-m", "-v", "-i", identifier]
        let register = ["-a", extensionURL.path]
        if registerCurrentCopy { _ = run(register) }
        guard let output = run(query) else { return apiEnabled ? .enabled : .unavailable }
        var result = status(apiEnabled: apiEnabled, registeredPlugins: output, extensionURL: extensionURL, version: version)
        if result == .registrationPending || result == .anotherCopySelected {
            if !registerCurrentCopy { _ = run(register) }
            // PlugInKit may expose the old record briefly after an in-place update.
            for _ in 0..<2 {
                guard let updated = run(query) else { return .unavailable }
                result = status(apiEnabled: apiEnabled, registeredPlugins: updated, extensionURL: extensionURL, version: version)
                if result != .registrationPending && result != .anotherCopySelected { break }
                Thread.sleep(forTimeInterval: 0.15)
            }
        }
        return result
    }

    static func status(apiEnabled: Bool, registeredPlugins: String, extensionURL: URL, version: String? = nil) -> Status {
        let expectedPath = normalizedPath(extensionURL)
        let records = registeredPlugins.split(separator: "\n").compactMap { line -> (marker: String, version: String, path: String)? in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count >= 4, let path = fields.last else { return nil }
            let header = String(fields[0]).trimmingCharacters(in: .whitespaces)
            guard let opening = header.lastIndex(of: "("), let closing = header.lastIndex(of: ")"), opening < closing else { return nil }
            let marker = header.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) ?? ""
            return (marker, String(header[header.index(after: opening)..<closing]),
                    normalizedPath(URL(fileURLWithPath: path.trimmingCharacters(in: .whitespaces))))
        }
        if let current = records.first(where: { $0.path == expectedPath }) {
            // An explicit disabled election always wins, including over a stale API result.
            if current.marker == "-" { return .disabled }
            if let version, current.version != version { return .registrationPending }
            switch current.marker {
            case "+": return .enabled
            case "=", "!": return .registrationPending
            case "?", "+!": return .unavailable
            default: return apiEnabled ? .enabled : .disabled
            }
        }
        if records.contains(where: { $0.marker == "+" }) { return .anotherCopySelected }
        return apiEnabled ? .enabled : .registrationPending
    }

    static func isEnabled(apiEnabled: Bool, registeredPlugins: String, extensionURL: URL) -> Bool {
        status(apiEnabled: apiEnabled, registeredPlugins: registeredPlugins, extensionURL: extensionURL) == .enabled
    }

    private static func normalizedPath(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }

    private static func runCommand(_ arguments: [String]) -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            let deadline = Date().addingTimeInterval(3)
            while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.025) }
            guard !process.isRunning else { process.terminate(); return nil }
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        } catch { return nil }
    }
}
