import AVFoundation
import Observation

enum OnboardingPermissionKind: String, CaseIterable, Hashable, Sendable {
    case camera
    case notifications
    case appLock
}

enum OnboardingPermissionState: Equatable, Sendable {
    case available
    case requesting
    case enabled
    case denied
    case unavailable
    case failed
}

enum OnboardingPermissionAction: Equatable, Sendable {
    case request
    case openSettings
    case none
}

enum OnboardingCameraAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case denied
    case restricted
    case authorized
    case unavailable
}

@MainActor
struct OnboardingCameraPermissionClient {
    let authorizationStatus: () -> OnboardingCameraAuthorizationStatus
    let requestAuthorization: () async -> Bool
}

extension OnboardingCameraPermissionClient {
    static var live: Self {
        Self(
            authorizationStatus: {
                guard AVCaptureDevice.default(for: .video) != nil else {
                    return .unavailable
                }

                return switch AVCaptureDevice.authorizationStatus(for: .video) {
                case .notDetermined: .notDetermined
                case .restricted: .restricted
                case .denied: .denied
                case .authorized: .authorized
                @unknown default: .unavailable
                }
            },
            requestAuthorization: {
                guard AVCaptureDevice.default(for: .video) != nil else {
                    return false
                }

                switch AVCaptureDevice.authorizationStatus(for: .video) {
                case .authorized:
                    return true
                case .notDetermined:
                    return await AVCaptureDevice.requestAccess(for: .video)
                case .restricted, .denied:
                    return false
                @unknown default:
                    return false
                }
            }
        )
    }
}

@MainActor
struct OnboardingNotificationPermissionClient {
    let authorizationStatus: () async -> LocalNotificationAuthorizationStatus
    let requestAuthorization: () async throws -> Bool
}

extension OnboardingNotificationPermissionClient {
    static func live(
        center: any UserNotificationCenterProviding =
            SystemUserNotificationCenter.shared
    ) -> Self {
        Self(
            authorizationStatus: {
                await center.authorizationStatus()
            },
            requestAuthorization: {
                try await center.requestAuthorization(options: [.alert, .sound])
            }
        )
    }
}

@MainActor
struct OnboardingAppLockClient {
    let isEnabled: () -> Bool
    let requestEnable: () async -> AppLockActivationResult
}

extension OnboardingAppLockClient {
    static func live(controller: AppLockController) -> Self {
        Self(
            isEnabled: {
                controller.preferences.isEnabled
            },
            requestEnable: {
                await controller.requestEnable()
            }
        )
    }
}

@MainActor
@Observable
final class OnboardingPermissionsModel {
    @ObservationIgnored private let camera: OnboardingCameraPermissionClient
    @ObservationIgnored private let notifications: OnboardingNotificationPermissionClient
    @ObservationIgnored private let appLock: OnboardingAppLockClient

    private var states: [OnboardingPermissionKind: OnboardingPermissionState] = [
        .camera: .available,
        .notifications: .available,
        .appLock: .available,
    ]
    private(set) var activeRequest: OnboardingPermissionKind?

    init(
        camera: OnboardingCameraPermissionClient,
        notifications: OnboardingNotificationPermissionClient,
        appLock: OnboardingAppLockClient
    ) {
        self.camera = camera
        self.notifications = notifications
        self.appLock = appLock
    }

    func state(
        for permission: OnboardingPermissionKind
    ) -> OnboardingPermissionState {
        states[permission, default: .available]
    }

    func action(
        for permission: OnboardingPermissionKind
    ) -> OnboardingPermissionAction {
        switch state(for: permission) {
        case .available, .failed:
            .request
        case .denied:
            .openSettings
        case .requesting, .enabled, .unavailable:
            .none
        }
    }

    func refresh() async {
        states[.camera] = Self.presentationState(
            for: camera.authorizationStatus()
        )
        states[.notifications] = Self.presentationState(
            for: await notifications.authorizationStatus()
        )
        states[.appLock] = appLock.isEnabled() ? .enabled : .available
    }

    func request(_ permission: OnboardingPermissionKind) async {
        guard activeRequest == nil else { return }

        activeRequest = permission
        states[permission] = .requesting
        defer { activeRequest = nil }

        switch permission {
        case .camera:
            let isAuthorized = await camera.requestAuthorization()
            states[permission] = isAuthorized ? .enabled : .denied
        case .notifications:
            do {
                let isAuthorized = try await notifications.requestAuthorization()
                states[permission] = isAuthorized ? .enabled : .denied
            } catch {
                states[permission] = .failed
            }
        case .appLock:
            switch await appLock.requestEnable() {
            case .enabled:
                states[permission] = .enabled
            case .cancelled:
                states[permission] = .available
            case .failed:
                states[permission] = .failed
            }
        }
    }

    private static func presentationState(
        for status: OnboardingCameraAuthorizationStatus
    ) -> OnboardingPermissionState {
        switch status {
        case .notDetermined:
            .available
        case .denied:
            .denied
        case .restricted, .unavailable:
            .unavailable
        case .authorized:
            .enabled
        }
    }

    private static func presentationState(
        for status: LocalNotificationAuthorizationStatus
    ) -> OnboardingPermissionState {
        switch status {
        case .notDetermined:
            .available
        case .denied:
            .denied
        case .authorized, .provisional, .ephemeral:
            .enabled
        }
    }
}
