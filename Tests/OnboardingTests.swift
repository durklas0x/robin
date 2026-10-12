import XCTest

final class OnboardingTests: XCTestCase {
    func testRequiredPermissionsCannotBeSkipped() {
        var progress = OnboardingProgress()
        XCTAssertTrue(progress.advance(extensionEnabled: false, finderAllowed: false))
        XCTAssertEqual(progress.step, .finderExtension)
        XCTAssertFalse(progress.advance(extensionEnabled: false, finderAllowed: true))
        XCTAssertEqual(progress.step, .finderExtension)
        XCTAssertTrue(progress.advance(extensionEnabled: true, finderAllowed: false))
        XCTAssertEqual(progress.step, .automation)
        XCTAssertFalse(progress.advance(extensionEnabled: true, finderAllowed: false))
        XCTAssertFalse(progress.isComplete)
    }

    func testCompletionRequiresTourAndBothPermissions() {
        var progress = OnboardingProgress()
        for _ in 0..<3 {
            XCTAssertTrue(progress.advance(extensionEnabled: true, finderAllowed: true))
            XCTAssertFalse(progress.isComplete)
        }
        XCTAssertEqual(progress.step, .tour)
        XCTAssertTrue(progress.advance(extensionEnabled: true, finderAllowed: true))
        XCTAssertTrue(progress.isComplete)
    }

    func testResumedTourRechecksRevokedPermissions() {
        for permissions in [(false, true), (true, false), (false, false)] {
            var progress = OnboardingProgress(step: .tour)
            XCTAssertFalse(progress.advance(extensionEnabled: permissions.0, finderAllowed: permissions.1))
            XCTAssertFalse(progress.isComplete)
            XCTAssertEqual(progress.step, .tour)
        }
    }

    func testReplayingKeepsInitialCompletionWhileNavigatingBack() {
        var progress = OnboardingProgress(step: .tour, isComplete: true)
        for _ in 0..<5 { progress.back() }
        XCTAssertEqual(progress.step, .welcome)
        XCTAssertTrue(progress.isComplete)
    }
}
