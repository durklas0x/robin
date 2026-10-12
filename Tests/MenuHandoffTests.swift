import AppKit
import XCTest

final class MenuHandoffTests: XCTestCase {
    func testEveryActionSurvivesMenuProxyWithoutObjectMetadata() throws {
        var store = MenuRequestStore()
        let folder = URL(fileURLWithPath: "/tmp/folder & 'quotes'/🗂", isDirectory: true)
        for action in ActionRequest.Action.allCases {
            let original = NSMenuItem(title: action.rawValue, action: nil, keyEquivalent: "")
            original.tag = store.register(ActionRequest(action: action, folder: folder))
            let proxy = NSMenuItem(title: original.title, action: nil, keyEquivalent: "")
            proxy.tag = original.tag
            XCTAssertNil(proxy.representedObject)
            let routed = try XCTUnwrap(store.request(for: proxy.tag))
            XCTAssertEqual(routed.action, action)
            XCTAssertEqual(routed.folder, folder)
            XCTAssertEqual(ActionRequest(url: routed.url)?.folder, folder)
        }
        XCTAssertNil(store.request(for: 0))
    }

    func testLaterMenuDoesNotReplaceEarlierRequest() {
        var store = MenuRequestStore()
        let folder = URL(fileURLWithPath: "/tmp/first", isDirectory: true)
        let earlier = store.register(ActionRequest(action: .copy, folder: folder))
        _ = store.register(ActionRequest(action: .editor, folder: URL(fileURLWithPath: "/tmp/other")))
        XCTAssertEqual(store.request(for: earlier)?.folder, folder)
    }
}
