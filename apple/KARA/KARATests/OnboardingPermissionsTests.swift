import Testing
@testable import KARA

@Suite("Onboarding permissions")
@MainActor
struct OnboardingPermissionsTests {
    @Test("Refreshing reflects the current system access")
    func refreshReflectsSystemAccess() async {
        let model = OnboardingPermissionsModel(
            camera: OnboardingCameraPermissionClient(
                authorizationStatus: { .authorized },
                requestAuthorization: { true }
            ),
            notifications: OnboardingNotificationPermissionClient(
                authorizationStatus: { .denied },
                requestAuthorization: { false }
            ),
            appLock: OnboardingAppLockClient(
                isEnabled: { false },
                requestEnable: { .cancelled }
            )
        )

        await model.refresh()

        #expect(model.state(for: .camera) == .enabled)
        #expect(model.state(for: .notifications) == .denied)
        #expect(model.state(for: .appLock) == .available)
        #expect(model.action(for: .notifications) == .openSettings)
    }

    @Test("Granting camera access checks the camera item")
    func grantingCameraAccessChecksItem() async {
        var requestCount = 0
        let model = OnboardingPermissionsModel(
            camera: OnboardingCameraPermissionClient(
                authorizationStatus: { .notDetermined },
                requestAuthorization: {
                    requestCount += 1
                    return true
                }
            ),
            notifications: OnboardingNotificationPermissionClient(
                authorizationStatus: { .notDetermined },
                requestAuthorization: { false }
            ),
            appLock: OnboardingAppLockClient(
                isEnabled: { false },
                requestEnable: { .cancelled }
            )
        )

        await model.request(.camera)

        #expect(requestCount == 1)
        #expect(model.state(for: .camera) == .enabled)
    }

    @Test("Granting notification access checks the notification item")
    func grantingNotificationAccessChecksItem() async {
        var requestCount = 0
        let model = OnboardingPermissionsModel(
            camera: OnboardingCameraPermissionClient(
                authorizationStatus: { .notDetermined },
                requestAuthorization: { false }
            ),
            notifications: OnboardingNotificationPermissionClient(
                authorizationStatus: { .notDetermined },
                requestAuthorization: {
                    requestCount += 1
                    return true
                }
            ),
            appLock: OnboardingAppLockClient(
                isEnabled: { false },
                requestEnable: { .cancelled }
            )
        )

        await model.request(.notifications)

        #expect(requestCount == 1)
        #expect(model.state(for: .notifications) == .enabled)
    }

    @Test("A successful authentication checks the app-lock item")
    func successfulAuthenticationChecksAppLockItem() async {
        var requestCount = 0
        let model = OnboardingPermissionsModel(
            camera: OnboardingCameraPermissionClient(
                authorizationStatus: { .notDetermined },
                requestAuthorization: { false }
            ),
            notifications: OnboardingNotificationPermissionClient(
                authorizationStatus: { .notDetermined },
                requestAuthorization: { false }
            ),
            appLock: OnboardingAppLockClient(
                isEnabled: { false },
                requestEnable: {
                    requestCount += 1
                    return .enabled
                }
            )
        )

        await model.request(.appLock)

        #expect(requestCount == 1)
        #expect(model.state(for: .appLock) == .enabled)
    }

    @Test("Refusing notification access marks the item as denied")
    func refusingNotificationAccessMarksItemDenied() async {
        let model = makeModel(
            notifications: OnboardingNotificationPermissionClient(
                authorizationStatus: { .notDetermined },
                requestAuthorization: { false }
            )
        )

        await model.request(.notifications)

        #expect(model.state(for: .notifications) == .denied)
        #expect(model.action(for: .notifications) == .openSettings)
    }

    @Test("A notification request error remains retryable")
    func notificationRequestErrorRemainsRetryable() async {
        let model = makeModel(
            notifications: OnboardingNotificationPermissionClient(
                authorizationStatus: { .notDetermined },
                requestAuthorization: { throw PermissionTestError.failed }
            )
        )

        await model.request(.notifications)

        #expect(model.state(for: .notifications) == .failed)
        #expect(model.action(for: .notifications) == .request)
    }

    @Test("A failed app-lock authentication remains retryable")
    func failedAppLockAuthenticationRemainsRetryable() async {
        let model = makeModel(
            appLock: OnboardingAppLockClient(
                isEnabled: { false },
                requestEnable: { .failed }
            )
        )

        await model.request(.appLock)

        #expect(model.state(for: .appLock) == .failed)
        #expect(model.action(for: .appLock) == .request)
    }

    @Test("A second system request cannot start while one is active")
    func serializesSystemRequests() async {
        let suspendedCamera = SuspendedPermissionRequest()
        var notificationRequestCount = 0
        let model = OnboardingPermissionsModel(
            camera: OnboardingCameraPermissionClient(
                authorizationStatus: { .notDetermined },
                requestAuthorization: {
                    await suspendedCamera.call()
                }
            ),
            notifications: OnboardingNotificationPermissionClient(
                authorizationStatus: { .notDetermined },
                requestAuthorization: {
                    notificationRequestCount += 1
                    return true
                }
            ),
            appLock: OnboardingAppLockClient(
                isEnabled: { false },
                requestEnable: { .cancelled }
            )
        )

        let cameraRequest = Task {
            await model.request(.camera)
        }
        while model.activeRequest == nil {
            await Task.yield()
        }

        await model.request(.notifications)
        #expect(notificationRequestCount == 0)

        suspendedCamera.resolve(true)
        await cameraRequest.value
        #expect(model.state(for: .camera) == .enabled)
    }

    private func makeModel(
        notifications: OnboardingNotificationPermissionClient =
            OnboardingNotificationPermissionClient(
                authorizationStatus: { .notDetermined },
                requestAuthorization: { false }
            ),
        appLock: OnboardingAppLockClient =
            OnboardingAppLockClient(
                isEnabled: { false },
                requestEnable: { .cancelled }
            )
    ) -> OnboardingPermissionsModel {
        OnboardingPermissionsModel(
            camera: OnboardingCameraPermissionClient(
                authorizationStatus: { .notDetermined },
                requestAuthorization: { false }
            ),
            notifications: notifications,
            appLock: appLock
        )
    }
}

private enum PermissionTestError: Error {
    case failed
}

@MainActor
private final class SuspendedPermissionRequest {
    private var continuation: CheckedContinuation<Bool, Never>?

    func call() async -> Bool {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func resolve(_ result: Bool) {
        continuation?.resume(returning: result)
        continuation = nil
    }
}
