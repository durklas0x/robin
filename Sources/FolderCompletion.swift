import Foundation

struct FolderCompletion {
    static func candidates(for input: String, relativeTo base: URL) -> [String] {
        guard !input.contains("\0"), !input.contains("://") else { return [] }
        let split = input.lastIndex(of: "/")
        let prefix = split.map { String(input[...$0]) } ?? ""
        let partial = split.map { String(input[input.index(after: $0)...]) } ?? input
        let directory: URL
        if input == "~" { return ["~/"] }
        if prefix.isEmpty { directory = base }
        else {
            guard let resolved = try? FolderPath.resolve(prefix, relativeTo: base) else { return [] }
            directory = resolved
        }
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return [] }
        return names.filter { name in
            (partial.hasPrefix(".") || !name.hasPrefix(".")) &&
            (partial.isEmpty || name.range(of: partial, options: [.anchored, .caseInsensitive]) != nil) &&
            FolderPath.isDirectory(directory.appendingPathComponent(name))
        }
        .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        .prefix(100)
        .map { prefix + $0 + "/" }
    }
}
