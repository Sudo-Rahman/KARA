import Foundation
import Observation

enum OnboardingMode: Equatable {
    case firstLaunch
    case replay
}

@MainActor
@Observable
final class AppFlow {
    enum Destination: Equatable {
        case onboarding(OnboardingMode)
        case main
    }

    static let completionKey = "kara.onboarding.hasCompleted"

    private let defaults: UserDefaults
    private(set) var destination: Destination

    init(
        defaults: UserDefaults = .standard,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        self.defaults = defaults

        if arguments.contains("-KARAResetOnboarding") {
            defaults.set(false, forKey: Self.completionKey)
        }

        if arguments.contains("-KARAShowOnboarding") || !defaults.bool(forKey: Self.completionKey) {
            destination = .onboarding(.firstLaunch)
        } else {
            destination = .main
        }
    }

    func completeOnboarding() {
        defaults.set(true, forKey: Self.completionKey)
        destination = .main
    }

    func skipOnboarding() {
        completeOnboarding()
    }

    func replayOnboarding() {
        destination = .onboarding(.replay)
    }

    func finishReplay() {
        destination = .main
    }
}
