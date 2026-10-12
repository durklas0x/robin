import Foundation

struct FolderPath {
    static func resolve(_ input: String, relativeTo base: URL) throws -> URL {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains("\0") else { throw InvalidPath() }
        if text.contains("://") {
            guard let url = URL(string: text), url.isFileURL,
                  url.host == nil || url.host == "" || url.host == "localhost" else { throw InvalidPath() }
            return url.standardizedFileURL
        }
        let expanded = (text as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL
        }
        return base.appendingPathComponent(expanded, isDirectory: true).standardizedFileURL
    }

    private struct InvalidPath: LocalizedError {
        var errorDescription: String? { "Enter a local folder path, such as ~/Documents." }
    }
}
