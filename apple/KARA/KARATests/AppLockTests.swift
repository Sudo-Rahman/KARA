import Foundation
import Testing
@testable import KARA

@Suite("App lock")
@MainActor
struct AppLockTests {
    @Test("A fresh install is unlocked with a one-minute delay")
    func freshInstallDefaults() {
        let preferences = makePreferences()

        #expect(!preferences.isEnabled)
        #expect(preferences.delay == .oneMinute)
    }

    @Test("Activation and delay persist")
    func preferencesPersist() {
        let (defaults, suite) = makeDefaults()
        let preferences = AppLockPreferences(defaults: defaults)

        preferences.setEnabled(true)
        preferences.delay = .fiveMinutes

        let restored = AppLockPreferences(defaults: defaults)
        #expect(restored.isEnabled)
        #expect(restored.delay == .fiveMinutes)
        defaults.removePersistentDomain(forName: suite)
    }

    @Test("An unknown stored delay falls back to one minute")
    func invalidStoredDelayFallsBack() {
        let (defaults, suite) = makeDefaults()
        defaults.set("unknown", forKey: AppLockPreferences.delayStorageKey)

        #expect(AppLockPreferences(defaults: defaults).delay == .oneMinute)
        defaults.removePersistentDomain(forName: suite)
    }

    @Test(
        "Each delay locks at its exact threshold",
        arguments: [
            (AppLockDelay.immediate, 0.0),
            (.oneMinute, 60.0),
            (.fiveMinutes, 300.0),
        ]
    )
    func locksAtThreshold(delay: AppLockDelay, elapsed: TimeInterval) async {
        let fixture = makeEnabledController(delay: delay)
        await fixture.unlockInitialLaunch()

        fixture.controller.didEnterBackground()
        fixture.clock.uptime += elapsed
        await fixture.controller.didBecomeActive()

        #expect(fixture.authenticator.callCount == 2)
        #expect(!fixture.controller.isLocked)
    }

    @Test(
        "Timed delays remain unlocked just before their threshold",
        arguments: [
            (AppLockDelay.oneMinute, 59.999),
            (.fiveMinutes, 299.999),
        ]
    )
    func staysUnlockedBeforeThreshold(
        delay: AppLockDelay,
        elapsed: TimeInterval
    ) async {
        let fixture = makeEnabledController(delay: delay)
        await fixture.unlockInitialLaunch()

        fixture.controller.didEnterBackground()
        fixture.clock.uptime += elapsed
        await fixture.controller.didBecomeActive()

        #expect(fixture.authenticator.callCount == 1)
        #expect(!fixture.controller.isLocked)
    }

    @Test("A cold launch with the preference enabled starts locked")
    func coldLaunchStartsLocked() {
        let fixture = makeEnabledController(delay: .oneMinute)

        #expect(fixture.controller.isLocked)
    }

    @Test("A successful activation persists the preference")
    func successfulActivation() async {
        let preferences = makePreferences()
        let authenticator = StubDeviceAuthenticator()
        let controller = AppLockController(
            preferences: preferences,
            authenticator: authenticator
        )

        #expect(await controller.requestEnable() == .enabled)
        #expect(preferences.isEnabled)
        #expect(!controller.isLocked)
    }

    @Test("A cancelled activation leaves the preference disabled")
    func cancelledActivation() async {
        let preferences = makePreferences()
        let authenticator = StubDeviceAuthenticator(result: .failure(.cancelled))
        let controller = AppLockController(
            preferences: preferences,
            authenticator: authenticator
        )

        #expect(await controller.requestEnable() == .cancelled)
        #expect(!preferences.isEnabled)
    }

    @Test("A failed activation leaves the preference disabled")
    func failedActivation() async {
        let preferences = makePreferences()
        let authenticator = StubDeviceAuthenticator(result: .failure(.unavailable))
        let controller = AppLockController(
            preferences: preferences,
            authenticator: authenticator
        )

        #expect(await controller.requestEnable() == .failed)
        #expect(!preferences.isEnabled)
    }

    @Test("Authentication-driven background changes do not start a lock timer")
    func authenticationBackgroundChangesAreIgnored() async {
        let preferences = makePreferences()
        let authenticator = SuspendingDeviceAuthenticator()
        let controller = AppLockController(
            preferences: preferences,
            authenticator: authenticator
        )

        let activation = Task {
            await controller.requestEnable()
        }
        await Task.yield()

        #expect(controller.isAuthenticating)
        controller.didEnterBackground()
        #expect(!controller.isLocked)
        #expect(await controller.requestEnable() == .cancelled)
        #expect(authenticator.callCount == 1)

        authenticator.succeed()
        #expect(await activation.value == .enabled)
        #expect(!controller.isLocked)
    }

    @Test("A cancelled unlock keeps the app locked")
    func cancelledUnlockStaysLocked() async {
        let fixture = makeEnabledController(
            delay: .oneMinute,
            result: .failure(.cancelled)
        )

        await fixture.controller.didBecomeActive()
        #expect(fixture.controller.isLocked)
        #expect(fixture.authenticator.callCount == 1)
    }

    @Test("Becoming active without entering background does not authenticate")
    func inactiveTransitionDoesNotAuthenticate() async {
        let fixture = makeEnabledController(delay: .immediate)
        await fixture.unlockInitialLaunch()

        await fixture.controller.didBecomeActive()

        #expect(fixture.authenticator.callCount == 1)
        #expect(!fixture.controller.isLocked)
    }

    @Test("Disabling clears transient lock state")
    func disablingClearsLockState() {
        let fixture = makeEnabledController(delay: .immediate)

        fixture.controller.didEnterBackground()
        fixture.controller.disable()

        #expect(!fixture.preferences.isEnabled)
        #expect(!fixture.controller.isLocked)
    }

    private func makePreferences() -> AppLockPreferences {
        let (defaults, _) = makeDefaults()
        return AppLockPreferences(defaults: defaults)
    }

    private func makeEnabledController(
        delay: AppLockDelay,
        result: Result<Void, DeviceAuthenticationError> = .success(())
    ) -> ControllerFixture {
        let preferences = makePreferences()
        preferences.delay = delay
        preferences.setEnabled(true)
        let authenticator = StubDeviceAuthenticator(result: result)
        let clock = TestClock()
        let controller = AppLockController(
            preferences: preferences,
            authenticator: authenticator,
            uptime: { clock.uptime }
        )
        return ControllerFixture(
            preferences: preferences,
            authenticator: authenticator,
            clock: clock,
            controller: controller
        )
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suite = "kara.tests.app-lock.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (defaults, suite)
    }
}

@MainActor
private final class StubDeviceAuthenticator: DeviceAuthenticating {
    var result: Result<Void, DeviceAuthenticationError>
    private(set) var callCount = 0

    init(result: Result<Void, DeviceAuthenticationError> = .success(())) {
        self.result = result
    }

    func authenticate(localizedReason: String) async throws {
        callCount += 1
        try result.get()
    }
}

@MainActor
private final class SuspendingDeviceAuthenticator: DeviceAuthenticating {
    private(set) var callCount = 0
    private var continuation: CheckedContinuation<Void, Never>?

    func authenticate(localizedReason: String) async throws {
        callCount += 1
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func succeed() {
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
private final class TestClock {
    var uptime: TimeInterval = 1_000
}

@MainActor
private struct ControllerFixture {
    let preferences: AppLockPreferences
    let authenticator: StubDeviceAuthenticator
    let clock: TestClock
    let controller: AppLockController

    func unlockInitialLaunch() async {
        await controller.didBecomeActive()
        #expect(!controller.isLocked)
        #expect(authenticator.callCount == 1)
    }
}
