import Foundation
import XCTest

final class FinderExtensionStatusTests: XCTestCase {
    private let current = URL(fileURLWithPath: "/Applications/Robin.app/Contents/PlugIns/RobinFinder.appex")

    func testEnabledCurrentCopyIsRecognizedWhenFinderSyncReportsFalse() {
        let record = "+    com.durklas0x.Robin.Finder(1.0.1)\tUUID\t2026-10-12 10:28:34 AM +0000\t\(current.path)\n (1 plug-in)\n"
        XCTAssertTrue(FinderExtensionStatus.isEnabled(apiEnabled: false, registeredPlugins: record, extensionURL: current))
    }

    func testDisabledAndSupersededCopiesDoNotUnlockSetup() {
        for marker in ["-", "=", "?", "!", " "] {
            let record = "\(marker)    com.durklas0x.Robin.Finder(1.0.1)\tUUID\tdate\t\(current.path)"
            XCTAssertFalse(FinderExtensionStatus.isEnabled(apiEnabled: false, registeredPlugins: record, extensionURL: current))
        }
    }

    func testEnabledDifferentCopyDoesNotUnlockSetup() {
        let record = "+    com.durklas0x.Robin.Finder(1.0.1)\tUUID\tdate\t/tmp/old/Robin.app/Contents/PlugIns/RobinFinder.appex"
        XCTAssertFalse(FinderExtensionStatus.isEnabled(apiEnabled: false, registeredPlugins: record, extensionURL: current))
        XCTAssertFalse(FinderExtensionStatus.isEnabled(apiEnabled: false, registeredPlugins: "", extensionURL: current))
    }
}
