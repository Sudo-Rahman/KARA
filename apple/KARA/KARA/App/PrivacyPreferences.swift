import Foundation
import Observation

@MainActor
@Observable
final class PrivacyPreferences {
    nonisolated static let storageKey = "kara.privacy.hidesSensitiveValues"

    var hidesSensitiveValues: Bool {
        didSet {
            defaults.set(hidesSensitiveValues, forKey: storageKey)
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let storageKey: String

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = PrivacyPreferences.storageKey
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        hidesSensitiveValues = defaults.bool(forKey: storageKey)
    }

    func toggle() {
        hidesSensitiveValues.toggle()
    }
}
