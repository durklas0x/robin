import Foundation
import XCTest

final class FolderPathTests: XCTestCase {
    func testAbsoluteAndRelativePaths() throws {
        let base = URL(fileURLWithPath: "/tmp/parent/current", isDirectory: true)
        XCTAssertEqual(try FolderPath.resolve("../sibling", relativeTo: base).path, "/tmp/parent/sibling")
        XCTAssertEqual(try FolderPath.resolve("/tmp/space & 'quote'/🗂", relativeTo: base).path,
                       "/tmp/space & 'quote'/🗂")
    }

    func testHomeAndFileURLs() throws {
        let base = URL(fileURLWithPath: "/tmp")
        XCTAssertEqual(try FolderPath.resolve("~/Documents", relativeTo: base).path,
                       NSHomeDirectory() + "/Documents")
        XCTAssertEqual(try FolderPath.resolve("file:///tmp/space%20here", relativeTo: base).path, "/tmp/space here")
    }

    func testInvalidAndRemoteInputsAreRejected() {
        let base = URL(fileURLWithPath: "/tmp")
        for input in ["", "  ", "bad\0path", "https://example.com/folder", "file://remote/tmp"] {
            XCTAssertThrowsError(try FolderPath.resolve(input, relativeTo: base), input)
        }
    }
}
