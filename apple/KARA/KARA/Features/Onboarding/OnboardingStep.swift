import Foundation
import SwiftUI

enum OnboardingStep: Int, CaseIterable, Identifiable, Hashable {
    case revelation
    case inventory
    case valuation
    case permissions
    case intelligence

    var id: String {
        switch self {
        case .revelation: "revelation"
        case .inventory: "inventory"
        case .valuation: "valuation"
        case .permissions: "permissions"
        case .intelligence: "intelligence"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .revelation: "onboarding.revelation.title"
        case .inventory: "onboarding.inventory.title"
        case .valuation: "onboarding.valuation.title"
        case .permissions: "onboarding.permissions.title"
        case .intelligence: "onboarding.intelligence.title"
        }
    }

    var body: LocalizedStringResource {
        switch self {
        case .revelation: "onboarding.revelation.body"
        case .inventory: "onboarding.inventory.body"
        case .valuation: "onboarding.valuation.body"
        case .permissions: "onboarding.permissions.body"
        case .intelligence: "onboarding.intelligence.body"
        }
    }

    var accentTitle: LocalizedStringResource {
        switch self {
        case .revelation: "onboarding.revelation.accentTitle"
        case .inventory: "onboarding.inventory.accentTitle"
        case .valuation: "onboarding.valuation.accentTitle"
        case .permissions: "onboarding.permissions.accentTitle"
        case .intelligence: "onboarding.intelligence.accentTitle"
        }
    }

    var action: LocalizedStringResource {
        switch self {
        case .revelation: "onboarding.revelation.action"
        case .inventory: "onboarding.inventory.action"
        case .valuation: "onboarding.valuation.action"
        case .permissions: "onboarding.permissions.action"
        case .intelligence: "onboarding.intelligence.action"
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
