import Foundation

struct OnboardingProgress {
    enum Step: Int, CaseIterable {
        case welcome, finderExtension, automation, tour
    }

    var step: Step = .welcome
    var isComplete = false

    func canContinue(extensionEnabled: Bool, finderAllowed: Bool) -> Bool {
        switch step {
        case .welcome: true
        case .finderExtension: extensionEnabled
        case .automation, .tour: extensionEnabled && finderAllowed
        }
    }

    @discardableResult
    mutating func advance(extensionEnabled: Bool, finderAllowed: Bool) -> Bool {
        guard canContinue(extensionEnabled: extensionEnabled, finderAllowed: finderAllowed) else { return false }
        if step == .tour {
            isComplete = true
        } else {
            step = Step(rawValue: step.rawValue + 1)!
        }
        return true
    }

    mutating func back() {
        step = Step(rawValue: max(0, step.rawValue - 1))!
    }
}
