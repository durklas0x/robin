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
    func testUpdatedAppRegistersOwnCopyBeforeReadingSelection() {
        let old = "+    com.durklas0x.Robin.Finder(1.1.0)\tUUID\tdate\t/tmp/old/Robin.app/Contents/PlugIns/RobinFinder.appex"
        let updated = "+    com.durklas0x.Robin.Finder(1.2.0)\tUUID\tdate\t\(current.path)"
        var registered = false
        var calls: [[String]] = []
        let status = FinderExtensionStatus.refresh(apiEnabled: false, extensionURL: current,
            identifier: "com.durklas0x.Robin.Finder", version: "1.2.0", registerCurrentCopy: true) { arguments in
            calls.append(arguments)
            if arguments == ["-a", self.current.path] { registered = true; return "" }
            return registered ? updated : old
        }
        XCTAssertEqual(status, .enabled)
        XCTAssertEqual(calls.first, ["-a", current.path])
        XCTAssertFalse(calls.contains { $0.contains("-e") || $0.contains("-r") })
    }

    func testEnabledOlderCopyIsReportedSeparatelyFromDisabled() {
        let old = "+    com.durklas0x.Robin.Finder(1.1.0)\tUUID\tdate\t/tmp/old/Robin.app/Contents/PlugIns/RobinFinder.appex"
        XCTAssertEqual(FinderExtensionStatus.status(apiEnabled: false, registeredPlugins: old, extensionURL: current), .anotherCopySelected)
        let disabled = "-    com.durklas0x.Robin.Finder(1.2.0)\tUUID\tdate\t\(current.path)"
        XCTAssertEqual(FinderExtensionStatus.status(apiEnabled: true, registeredPlugins: disabled, extensionURL: current), .disabled)
    }

    func testOldVersionAtSamePathRequiresFreshRegistration() {
        let old = "+    com.durklas0x.Robin.Finder(1.1.0)\tUUID\tdate\t\(current.path)"
        XCTAssertEqual(FinderExtensionStatus.status(apiEnabled: false, registeredPlugins: old,
                                                  extensionURL: current, version: "1.2.0"), .registrationPending)
    }

    func testRegistrationDoesNotEnableAUserDisabledExtension() {
        let record = "-    com.durklas0x.Robin.Finder(1.2.0)\tUUID\tdate\t\(current.path)"
        var calls: [[String]] = []
        let status = FinderExtensionStatus.refresh(apiEnabled: false, extensionURL: current,
            identifier: "com.durklas0x.Robin.Finder", version: "1.2.0", registerCurrentCopy: true) { arguments in
            calls.append(arguments)
            return arguments.first == "-a" ? "" : record
        }
        XCTAssertEqual(status, .disabled)
        XCTAssertFalse(calls.contains { $0.contains("-e") || $0.contains("-r") })
    }

    func testSettingsRecheckRepairsStaleRegistrationWithoutChangingElection() {
        let old = "+    com.durklas0x.Robin.Finder(1.1.0)\tUUID\tdate\t\(current.path)"
        let updated = "+    com.durklas0x.Robin.Finder(1.2.0)\tUUID\tdate\t\(current.path)"
        var registered = false
        var calls: [[String]] = []
        let status = FinderExtensionStatus.refresh(apiEnabled: false, extensionURL: current,
            identifier: "com.durklas0x.Robin.Finder", version: "1.2.0", registerCurrentCopy: false) { arguments in
            calls.append(arguments)
            if arguments.first == "-a" { registered = true; return "" }
            return registered ? updated : old
        }
        XCTAssertEqual(status, .enabled)
        XCTAssertEqual(calls.filter { $0.first == "-a" }, [["-a", current.path]])
        XCTAssertFalse(calls.contains { $0.contains("-e") || $0.contains("-r") })
    }

    func testHealthyAndDisabledCopiesAreNotReregisteredDuringRechecks() {
        for marker in ["+", "-"] {
            var calls: [[String]] = []
            let record = "\(marker)    com.durklas0x.Robin.Finder(1.2.0)\tUUID\tdate\t\(current.path)"
            _ = FinderExtensionStatus.refresh(apiEnabled: false, extensionURL: current,
                identifier: "com.durklas0x.Robin.Finder", version: "1.2.0", registerCurrentCopy: false) { arguments in
                calls.append(arguments)
                return record
            }
            XCTAssertEqual(calls.count, 1)
            XCTAssertEqual(calls.first?.first, "-m")
        }
    }

    func testDelayedRegistrationAndRegistryFailure() {
        var queries = 0
        let old = "+    com.durklas0x.Robin.Finder(1.1.0)\tUUID\tdate\t\(current.path)"
        let updated = "+    com.durklas0x.Robin.Finder(1.2.0)\tUUID\tdate\t\(current.path)"
        let result = FinderExtensionStatus.refresh(apiEnabled: false, extensionURL: current,
            identifier: "com.durklas0x.Robin.Finder", version: "1.2.0", registerCurrentCopy: true) { arguments in
            if arguments.first == "-a" { return "" }
            queries += 1
            return queries < 3 ? old : updated
        }
        XCTAssertEqual(result, .enabled)
        XCTAssertEqual(queries, 3)
        XCTAssertEqual(FinderExtensionStatus.refresh(apiEnabled: false, extensionURL: current,
            identifier: "com.durklas0x.Robin.Finder", version: "1.2.0", registerCurrentCopy: false, run: { _ in nil }), .unavailable)
    }

}
