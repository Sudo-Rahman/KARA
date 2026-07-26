import Foundation
import Observation

@MainActor
@Observable
final class AIFormAutofillPreferences {
    nonisolated static let storageKey = "kara.ai-form-autofill.is-enabled"

    var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: storageKey)
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let storageKey: String

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = AIFormAutofillPreferences.storageKey
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        isEnabled = defaults.bool(forKey: storageKey)
    }

    func disable() {
        isEnabled = false
    }
}
