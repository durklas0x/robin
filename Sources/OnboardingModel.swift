import AppKit
import Combine
import CoreServices
import FinderSync
import ServiceManagement

@MainActor
final class OnboardingModel: ObservableObject {
    enum AutomationStatus: Equatable {
        case checking, allowed, notRequested, denied, finderNotRunning, unavailable(Int32)
    }

    @Published private(set) var progress: OnboardingProgress
    @Published private(set) var extensionStatus: FinderExtensionStatus.Status = .checking
    var extensionEnabled: Bool { extensionStatus == .enabled }
    @Published private(set) var automation: AutomationStatus = .checking
    @Published private(set) var checking = false
    @Published private(set) var loginEnabled = false
    @Published private(set) var loginNeedsApproval = false
    @Published private(set) var loginError = ""
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        progress = OnboardingProgress(
            step: OnboardingProgress.Step(rawValue: defaults.integer(forKey: "onboarding.step")) ?? .welcome,
            isComplete: defaults.bool(forKey: "onboarding.complete"))
        refreshLogin()
    }

    var canContinue: Bool {
        !checking && progress.canContinue(extensionEnabled: extensionEnabled, finderAllowed: automation == .allowed)
    }

    func begin() {
        if progress.isComplete { progress.step = .welcome }
    }

    func refresh(requestAutomation: Bool = false) async {
        guard !checking else { return }
        checking = true
        extensionStatus = await FinderExtensionStatus.check()
        refreshLogin()
        // Apple requires this call off the main thread, including permission preflight.
        let status = await Task.detached {
            let target = NSAppleEventDescriptor(bundleIdentifier: "com.apple.finder")
            return AEDeterminePermissionToAutomateTarget(target.aeDesc, AEEventClass(typeWildCard),
                                                        AEEventID(typeWildCard), requestAutomation)
        }.value
        switch status {
        case noErr: automation = .allowed
        case OSStatus(errAEEventWouldRequireUserConsent): automation = .notRequested
        case OSStatus(errAEEventNotPermitted): automation = .denied
        case OSStatus(procNotFound): automation = .finderNotRunning
        default: automation = .unavailable(status)
        }
        extensionStatus = await FinderExtensionStatus.check()
        checking = false
    }

    /// Returns true only when the last step completes with both permissions still granted.
    func advance() async -> Bool {
        await refresh()
        guard canContinue else { return false }
        let finishing = progress.step == .tour
        progress.advance(extensionEnabled: extensionEnabled, finderAllowed: automation == .allowed)
        if finishing { defaults.set(true, forKey: "onboarding.complete") }
        saveStep()
        return finishing
    }

    func back() {
        progress.back()
        saveStep()
    }

    func reviewPermissions() {
        progress.step = extensionEnabled ? .automation : .finderExtension
        saveStep()
    }

    func setLoginEnabled(_ enabled: Bool) {
        loginError = ""
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            loginError = "Could not change launch at login: \(error.localizedDescription)"
        }
        refreshLogin()
    }

    func openAutomationSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
    }

    func openFinder() {
        NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser)
    }

    private func refreshLogin() {
        let status = SMAppService.mainApp.status
        loginEnabled = status == .enabled || status == .requiresApproval
        loginNeedsApproval = status == .requiresApproval
    }

    private func saveStep() {
        // Replaying the tour never resets first-run completion or saved progress.
        if !progress.isComplete { defaults.set(progress.step.rawValue, forKey: "onboarding.step") }
    }
}
