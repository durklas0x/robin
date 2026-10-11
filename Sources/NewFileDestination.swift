import Foundation

struct NewFileDestination {
    static func url(name: String, in folder: URL) throws -> URL {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              name != ".", name != "..", !name.contains("/"), !name.contains("\0") else {
            throw InvalidName()
        }
        return folder.appendingPathComponent(name, isDirectory: false)
    }

    private struct InvalidName: LocalizedError {
        var errorDescription: String? { "Enter a file name without folder separators." }
    }
}
