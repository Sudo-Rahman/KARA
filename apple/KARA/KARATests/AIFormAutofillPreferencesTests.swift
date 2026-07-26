import Foundation
import Testing
@testable import KARA

@Suite("AI form autofill preferences")
@MainActor
struct AIFormAutofillPreferencesTests {
    @Test("A fresh install keeps automatic extraction disabled")
    func freshInstallDefaultsToDisabled() {
        let defaults = makeDefaults()

        #expect(!AIFormAutofillPreferences(defaults: defaults).isEnabled)
    }

    @Test("The choice persists and can be reversed")
    func preferencePersistsBothStates() {
        let defaults = makeDefaults()
        let preferences = AIFormAutofillPreferences(defaults: defaults)

        preferences.isEnabled = true
        #expect(AIFormAutofillPreferences(defaults: defaults).isEnabled)

        preferences.isEnabled = false
        #expect(!AIFormAutofillPreferences(defaults: defaults).isEnabled)
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "kara.tests.ai-autofill.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
