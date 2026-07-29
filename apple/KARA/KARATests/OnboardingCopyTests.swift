import Foundation
import Testing
@testable import KARA

@Suite("Onboarding copy")
struct OnboardingCopyTests {
    @Test("The opening promise is premium in French and English")
    func openingPromiseIsLocalized() {
        let step = OnboardingStep.revelation

        #expect(
            localized(step.title, locale: "fr") == "Votre collection."
        )
        #expect(
            localized(step.accentTitle, locale: "fr")
                == "Dans ses moindres détails."
        )
        #expect(
            localized(step.title, locale: "en") == "Your collection."
        )
        #expect(
            localized(step.accentTitle, locale: "en")
                == "Down to every detail."
        )
    }

    private func localized(
        _ resource: LocalizedStringResource,
        locale: String
    ) -> String {
        var localizedResource = resource
        localizedResource.locale = Locale(identifier: locale)
        return String(localized: localizedResource)
    }
}
