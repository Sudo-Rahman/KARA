import Foundation
import Testing
@testable import KARA

@Suite("Privacy preferences")
@MainActor
struct PrivacyPreferencesTests {
    @Test
    func freshInstallShowsSensitiveValues() {
        let defaults = makeDefaults()
        let preferences = PrivacyPreferences(defaults: defaults)

        #expect(!preferences.hidesSensitiveValues)
    }

    @Test
    func togglePersistsHiddenValuesAcrossInstances() {
        let defaults = makeDefaults()
        let preferences = PrivacyPreferences(defaults: defaults)

        preferences.toggle()

        #expect(preferences.hidesSensitiveValues)
        #expect(PrivacyPreferences(defaults: defaults).hidesSensitiveValues)
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "kara.tests.privacy.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
