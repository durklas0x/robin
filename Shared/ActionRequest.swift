import Foundation

struct ActionRequest {
    enum Action: String, CaseIterable { case newFile, copy, terminal, editor }
    let action: Action
    let folder: URL

    init(action: Action, folder: URL) {
        self.action = action
        self.folder = folder
    }

    init?(url: URL) {
        guard let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == "robin", parts.host == "action",
              let name = parts.queryItems?.first(where: { $0.name == "name" })?.value,
              let action = Action(rawValue: name),
              let path = parts.queryItems?.first(where: { $0.name == "folder" })?.value,
              path.hasPrefix("/"), !path.contains("\0") else { return nil }
        self.action = action
        self.folder = URL(fileURLWithPath: path, isDirectory: true)
    }

    var url: URL {
        var parts = URLComponents()
        parts.scheme = "robin"
        parts.host = "action"
        parts.queryItems = [URLQueryItem(name: "name", value: action.rawValue),
                            URLQueryItem(name: "folder", value: folder.path)]
        return parts.url!
    }
}
