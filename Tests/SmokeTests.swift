import Foundation
import CoreGraphics
import XCTest

final class SmokeTests: XCTestCase {
    func testActionURLRoundTrip() throws {
        let path = "/tmp/space 'quote' & percent% #hash /🗂"
        let request = ActionRequest(action: .newFile, folder: URL(fileURLWithPath: path))
        let decoded = try XCTUnwrap(ActionRequest(url: request.url))
        XCTAssertEqual(decoded.folder.path, path)
        XCTAssertEqual(decoded.action, .newFile)
    }

    func testInvalidRequestsAreRejected() throws {
        for input in ["https://action?name=copy&folder=/tmp", "pathlet://action?name=unknown&folder=/tmp",
                      "pathlet://action?name=copy&folder=relative", "pathlet://action?name=copy&folder=/%00"] {
            XCTAssertNil(ActionRequest(url: try XCTUnwrap(URL(string: input))), input)
        }
    }

    func testBarStaysOnSecondaryDisplayAndFallsBackAtBottomEdge() {
        let display = CGRect(x: -1440, y: -400, width: 1440, height: 900)
        for window in [CGRect(x: -1800, y: -380, width: 800, height: 600),
                       CGRect(x: -800, y: 0, width: 900, height: 400)] {
            let bar = BarPlacement.frame(below: window, visibleFrame: display)
            XCTAssertTrue(display.contains(bar))
            if window.minY - 46 >= display.minY { XCTAssertLessThan(bar.maxY, window.minY) }
            else { XCTAssertGreaterThanOrEqual(bar.minY, window.minY) }
        }
    }

    func testNewFileDestinationStaysInSelectedFolder() throws {
        let folder = URL(fileURLWithPath: "/tmp/pathlet-test", isDirectory: true)
        let file = try NewFileDestination.url(name: "notes ' & 🗂.txt", in: folder)
        XCTAssertEqual(file.deletingLastPathComponent(), folder)
        for name in ["", "   ", ".", "..", "../escape", "/absolute", "bad\0name"] {
            XCTAssertThrowsError(try NewFileDestination.url(name: name, in: folder), name)
        }
    }
}
