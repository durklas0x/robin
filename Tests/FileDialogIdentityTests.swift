import Foundation
import XCTest

final class FileDialogIdentityTests: XCTestCase {
    func testOnlyNativeFilePanelsMatch() {
        XCTAssertTrue(FileDialogIdentity.isPanel(identifier: "open-panel"))
        XCTAssertTrue(FileDialogIdentity.isPanel(identifier: "save-panel"))
        for id in ["", "GoToWindow", "document-window", "alert"] {
            XCTAssertFalse(FileDialogIdentity.isPanel(identifier: id))
        }
    }

    func testFolderEvidenceExcludesSidebarAndSearchContainers() {
        for id in ["IconView", "ListView", "ColumnView"] { XCTAssertTrue(FileDialogIdentity.isBrowser(identifier: id)) }
        for id in ["sidebar", "SearchField", "", "GoToWindow"] { XCTAssertFalse(FileDialogIdentity.isBrowser(identifier: id)) }
    }

    func testFolderRequiresUnambiguousMatchingItemParents() {
        let documents = URL(fileURLWithPath: "/Users/example/Documents", isDirectory: true)
        let desktop = URL(fileURLWithPath: "/Users/example/Desktop", isDirectory: true)
        XCTAssertEqual(FileDialogIdentity.folder(from: [documents, documents, desktop], named: "Documents"), documents)
        XCTAssertNil(FileDialogIdentity.folder(from: [], named: "Documents"))
        XCTAssertNil(FileDialogIdentity.folder(from: [desktop], named: "Documents"))
        XCTAssertNil(FileDialogIdentity.folder(from: [documents, URL(fileURLWithPath: "/other/Documents")], named: "Documents"))
    }
}
