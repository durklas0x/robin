import Foundation
import FinderSync

enum FinderExtensionStatus {
    @MainActor
    static func check() async -> Bool {
        let apiEnabled = FIFinderSyncController.isExtensionEnabled
        if apiEnabled { return true }
        guard let directory = Bundle.main.builtInPlugInsURL else { return false }
        let extensionURL = directory.appendingPathComponent("RobinFinder.appex")
        guard let identifier = Bundle(url: extensionURL)?.bundleIdentifier else { return false }
        let output = await Task.detached {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/pluginkit")
            process.arguments = ["-m", "-v", "-i", identifier]
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else { return "" }
                return String(decoding: data, as: UTF8.self)
            } catch { return "" }
        }.value
        return isEnabled(apiEnabled: apiEnabled, registeredPlugins: output, extensionURL: extensionURL)
    }

    static func isEnabled(apiEnabled: Bool, registeredPlugins: String, extensionURL: URL) -> Bool {
        if apiEnabled { return true }
        let expectedPath = extensionURL.standardizedFileURL.resolvingSymlinksInPath().path
        // PlugInKit's documented '+' election means the user enabled this extension.
        // Only its selected copy may satisfy setup, never an older app elsewhere.
        return registeredPlugins.split(separator: "\n").contains { line in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard fields.count >= 2,
                  fields[0].trimmingCharacters(in: .whitespaces).hasPrefix("+"),
                  let path = fields.last else { return false }
            let registeredURL = URL(fileURLWithPath: path.trimmingCharacters(in: .whitespaces))
            return registeredURL.standardizedFileURL.resolvingSymlinksInPath().path == expectedPath
        }
    }
}
