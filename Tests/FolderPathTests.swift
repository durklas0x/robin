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

    func testSystemTemporaryDirectoryAndSymlinkDestinationsAreFolders() throws {
        let base = URL(fileURLWithPath: "/Users", isDirectory: true)
        for input in ["/private/tmp", "/tmp", "file:///private/tmp"] {
            let destination = try FolderPath.resolve(input, relativeTo: base)
            XCTAssertTrue(FolderPath.isDirectory(destination), input)
        }
    }

    func testDirectoryValidationFollowsLinksAndRejectsFilesAndMissingPaths() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("file")
        try Data().write(to: file)
        let link = root.appendingPathComponent("folder-link")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: root)
        let fileLink = root.appendingPathComponent("file-link")
        try FileManager.default.createSymbolicLink(at: fileLink, withDestinationURL: file)
        XCTAssertTrue(FolderPath.isDirectory(root))
        XCTAssertTrue(FolderPath.isDirectory(link))
        XCTAssertFalse(FolderPath.isDirectory(file))
        XCTAssertFalse(FolderPath.isDirectory(fileLink))
        XCTAssertFalse(FolderPath.isDirectory(root.appendingPathComponent("missing")))
    }

    func testInvalidAndRemoteInputsAreRejected() {
        let base = URL(fileURLWithPath: "/tmp")
        for input in ["", "  ", "bad\0path", "https://example.com/folder", "file://remote/tmp"] {
            XCTAssertThrowsError(try FolderPath.resolve(input, relativeTo: base), input)
        }
    }
}
