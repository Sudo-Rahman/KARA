import Foundation
import LocalAuthentication
import Observation

nonisolated enum DeviceAuthenticationError: Error, Equatable, Sendable {
    case cancelled
    case unavailable
    case failed
}

@MainActor
protocol DeviceAuthenticating {
    func authenticate(localizedReason: String) async throws
}

@MainActor
final class LocalDeviceAuthenticator: DeviceAuthenticating {
    func authenticate(localizedReason: String) async throws {
        let context = LAContext()
        var availabilityError: NSError?

        guard context.canEvaluatePolicy(
            .deviceOwnerAuthentication,
            error: &availabilityError
        ) else {
            throw Self.map(availabilityError)
        }

        do {
            guard try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: localizedReason
            ) else {
                throw DeviceAuthenticationError.failed
            }
        } catch {
            throw Self.map(error)
        }
    }

    private static func map(_ error: (any Error)?) -> DeviceAuthenticationError {
        guard let error else { return .unavailable }

        return switch LAError.Code(rawValue: (error as NSError).code) {
        case .userCancel, .appCancel, .systemCancel:
            DeviceAuthenticationError.cancelled
        case .passcodeNotSet, .biometryNotAvailable, .biometryNotEnrolled:
            DeviceAuthenticationError.unavailable
        default:
            DeviceAuthenticationError.failed
        }
    }
}

nonisolated enum AppLockActivationResult: Equatable, Sendable {
    case enabled
    case cancelled
    case failed
}

@MainActor
@Observable
final class AppLockController {
    private(set) var isLocked: Bool
    private(set) var isAuthenticating = false

    let preferences: AppLockPreferences

    @ObservationIgnored private let authenticator: any DeviceAuthenticating
    @ObservationIgnored private let uptime: () -> TimeInterval
    @ObservationIgnored private var enteredBackgroundAt: TimeInterval?

    init(
        preferences: AppLockPreferences,
        authenticator: (any DeviceAuthenticating)? = nil,
        uptime: @escaping () -> TimeInterval = {
            ProcessInfo.processInfo.systemUptime
        }
    ) {
        self.preferences = preferences
        self.authenticator = authenticator ?? LocalDeviceAuthenticator()
        self.uptime = uptime
        isLocked = preferences.isEnabled
    }

    func requestEnable() async -> AppLockActivationResult {
        guard !preferences.isEnabled else { return .enabled }
        guard !isAuthenticating else { return .cancelled }

        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            try await authenticator.authenticate(
                localizedReason: String(localized: "app-lock.authentication.enable-reason")
            )
            preferences.setEnabled(true)
            enteredBackgroundAt = nil
            isLocked = false
            return .enabled
        } catch DeviceAuthenticationError.cancelled {
            return .cancelled
        } catch {
            return .failed
        }
    }

    func disable() {
        preferences.setEnabled(false)
        enteredBackgroundAt = nil
        isLocked = false
    }

    func didEnterBackground() {
        guard preferences.isEnabled, !isAuthenticating else { return }
        if enteredBackgroundAt == nil {
            enteredBackgroundAt = uptime()
        }
        isLocked = true
    }

    func didBecomeActive() async {
        guard preferences.isEnabled else {
            enteredBackgroundAt = nil
            isLocked = false
            return
        }
        guard !isAuthenticating else { return }

        if let enteredBackgroundAt {
            let elapsed = max(0, uptime() - enteredBackgroundAt)
            self.enteredBackgroundAt = nil

            guard elapsed >= preferences.delay.duration else {
                isLocked = false
                return
            }
        } else if !isLocked {
            return
        }

        isLocked = true
        await authenticateForUnlock()
    }

    private func authenticateForUnlock() async {
        guard !isAuthenticating else { return }

        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            try await authenticator.authenticate(
                localizedReason: String(localized: "app-lock.authentication.unlock-reason")
            )
            isLocked = false
        } catch {
            isLocked = true
        }
    }
}
