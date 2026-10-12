import Foundation
import XCTest

final class FolderCompletionTests: XCTestCase {
    func testOnlyFoldersIncludingSymlinksAreCompleted() throws {
        try withFolders { base in
            let input = base.path + "/Doc"
            XCTAssertEqual(FolderCompletion.candidates(for: input, relativeTo: base),
                           [base.path + "/Docs Link/", base.path + "/Documents/", base.path + "/Documents 🗂/"])
        }
    }

    func testRelativePathsSpacesUnicodeAndHiddenFolders() throws {
        try withFolders { base in
            XCTAssertEqual(FolderCompletion.candidates(for: "doc", relativeTo: base),
                           ["Docs Link/", "Documents/", "Documents 🗂/"])
            XCTAssertEqual(FolderCompletion.candidates(for: "Documents 🗂", relativeTo: base), ["Documents 🗂/"])
            XCTAssertEqual(FolderCompletion.candidates(for: ".s", relativeTo: base), [".secret/"])
            XCTAssertEqual(FolderCompletion.candidates(for: "", relativeTo: base),
                           ["Docs Link/", "Documents/", "Documents 🗂/"])
            XCTAssertEqual(FolderCompletion.candidates(for: "../" + base.lastPathComponent + "/Docu", relativeTo: base),
                           ["../" + base.lastPathComponent + "/Documents/", "../" + base.lastPathComponent + "/Documents 🗂/"])
        }
    }

    func testHomeAndUnavailablePaths() {
        let base = URL(fileURLWithPath: "/private/tmp")
        XCTAssertEqual(FolderCompletion.candidates(for: "~", relativeTo: base), ["~/"])
        XCTAssertEqual(FolderCompletion.candidates(for: "/does-not-exist/Doc", relativeTo: base), [])
        XCTAssertEqual(FolderCompletion.candidates(for: "https://example.com", relativeTo: base), [])
        XCTAssertEqual(FolderCompletion.candidates(for: "bad\0path", relativeTo: base), [])
    }

    private func withFolders(_ test: (URL) throws -> Void) throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: base) }
        for name in ["Documents", "Documents 🗂", ".secret"] {
            try FileManager.default.createDirectory(at: base.appendingPathComponent(name), withIntermediateDirectories: true)
        }
        try Data().write(to: base.appendingPathComponent("Document.txt"))
        try FileManager.default.createSymbolicLink(at: base.appendingPathComponent("Docs Link"),
                                                  withDestinationURL: base.appendingPathComponent("Documents"))
        try test(base)
    }
}
