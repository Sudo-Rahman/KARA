import Foundation
import SwiftUI

enum OnboardingStep: Int, CaseIterable, Identifiable, Hashable {
    case revelation
    case organization
    case privacy

    var id: String {
        switch self {
        case .revelation: "revelation"
        case .organization: "organization"
        case .privacy: "privacy"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .revelation: "onboarding.revelation.title"
        case .organization: "onboarding.organization.title"
        case .privacy: "onboarding.privacy.title"
        }
    }

    var body: LocalizedStringResource {
        switch self {
        case .revelation: "onboarding.revelation.body"
        case .organization: "onboarding.organization.body"
        case .privacy: "onboarding.privacy.body"
        }
    }

    var accentTitle: LocalizedStringResource {
        switch self {
        case .revelation: "onboarding.revelation.accentTitle"
        case .organization: "onboarding.organization.accentTitle"
        case .privacy: "onboarding.privacy.accentTitle"
        }
    }

    var action: LocalizedStringResource {
        switch self {
        case .revelation: "onboarding.revelation.action"
        case .organization: "onboarding.organization.action"
        case .privacy: "onboarding.privacy.action"
        }
    }

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    var progressText: String {
        let format = String(
            localized: "onboarding.progress.format",
            defaultValue: "Step %1$lld of %2$lld"
        )
        return String(
            format: format,
            locale: .current,
            rawValue + 1,
            Self.allCases.count
        )
    }
}

enum OnboardingAdvanceResult: Equatable {
    case advanced(OnboardingStep)
    case completed
}

struct OnboardingFlowState: Equatable {
    private(set) var step: OnboardingStep = .revelation

    mutating func select(_ step: OnboardingStep) {
        self.step = step
    }

    mutating func advance() -> OnboardingAdvanceResult {
        guard let next = step.next else {
            return .completed
        }

        step = next
        return .advanced(next)
    }
}

struct OnboardingMotionProfile: Equatable {
    let sceneMotionEnabled: Bool
    let parallaxEnabled: Bool
    let transitionDuration: TimeInterval

    init(reduceMotion: Bool) {
        sceneMotionEnabled = !reduceMotion
        parallaxEnabled = !reduceMotion
        transitionDuration = reduceMotion ? 0.18 : 0.65
    }
}
