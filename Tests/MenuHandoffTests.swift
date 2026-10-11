import AppKit

@main
struct MenuHandoffTests {
    static func main() {
        var store = MenuRequestStore()
        let folder = URL(fileURLWithPath: "/tmp/folder & 'quotes'/🗂", isDirectory: true)
        for action in ActionRequest.Action.allCases {
            let original = NSMenuItem(title: action.rawValue, action: nil, keyEquivalent: "")
            original.tag = store.register(ActionRequest(action: action, folder: folder))
            // Finder sends a proxy with scalar properties, without representedObject.
            let proxy = NSMenuItem(title: original.title, action: nil, keyEquivalent: "")
            proxy.tag = original.tag
            precondition(proxy.representedObject == nil)
            let routed = store.request(for: proxy.tag)!
            precondition(routed.action == action && routed.folder == folder)
            precondition(ActionRequest(url: routed.url)?.folder == folder)
        }
        precondition(store.request(for: 0) == nil)
        // A subsequent menu must not replace a request from a still-open menu.
        let earlier = store.register(ActionRequest(action: .copy, folder: folder))
        _ = store.register(ActionRequest(action: .editor, folder: URL(fileURLWithPath: "/tmp/other")))
        precondition(store.request(for: earlier)?.folder == folder)
        print("PASS: all four Finder menu proxy actions retain their request without object metadata")
    }
}
