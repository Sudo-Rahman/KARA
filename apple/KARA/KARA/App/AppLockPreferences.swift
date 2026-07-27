import Foundation
import Observation

nonisolated enum AppLockDelay: String, CaseIterable, Sendable {
    case immediate
    case oneMinute
    case fiveMinutes

    var duration: TimeInterval {
        switch self {
        case .immediate:
            0
        case .oneMinute:
            60
        case .fiveMinutes:
            300
        }
    }
}

@MainActor
@Observable
final class AppLockPreferences {
    nonisolated static let isEnabledStorageKey = "kara.app-lock.is-enabled"
    nonisolated static let delayStorageKey = "kara.app-lock.delay"

    private(set) var isEnabled: Bool

    var delay: AppLockDelay {
        didSet {
            defaults.set(delay.rawValue, forKey: delayStorageKey)
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let isEnabledStorageKey: String
    @ObservationIgnored private let delayStorageKey: String

    init(
        defaults: UserDefaults = .standard,
        isEnabledStorageKey: String = AppLockPreferences.isEnabledStorageKey,
        delayStorageKey: String = AppLockPreferences.delayStorageKey
    ) {
        self.defaults = defaults
        self.isEnabledStorageKey = isEnabledStorageKey
        self.delayStorageKey = delayStorageKey
        isEnabled = defaults.bool(forKey: isEnabledStorageKey)
        delay = defaults.string(forKey: delayStorageKey)
            .flatMap(AppLockDelay.init(rawValue:))
            ?? .oneMinute
    }

    func setEnabled(_ isEnabled: Bool) {
        self.isEnabled = isEnabled
        defaults.set(isEnabled, forKey: isEnabledStorageKey)
    }
}
