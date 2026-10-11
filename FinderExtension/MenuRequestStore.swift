import Foundation

/// Finder copies menu items across a process boundary; object metadata is not preserved.
/// Keep requests in the extension and put only the numeric lookup key on the menu item.
struct MenuRequestStore {
    private var nextTag = 1
    private var requests: [Int: ActionRequest] = [:]

    mutating func register(_ request: ActionRequest) -> Int {
        let tag = nextTag
        nextTag += 1
        requests[tag] = request
        // Preserve overlapping menus without retaining every menu ever opened.
        requests.removeValue(forKey: tag - 256)
        return tag
    }

    func request(for tag: Int) -> ActionRequest? { requests[tag] }
}
