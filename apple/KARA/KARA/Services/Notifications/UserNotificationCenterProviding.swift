import Foundation
import UserNotifications

nonisolated enum LocalNotificationAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
}

nonisolated struct LocalNotificationAuthorizationOptions:
    OptionSet,
    Sendable
{
    let rawValue: Int

    static let alert = Self(rawValue: 1 << 0)
    static let sound = Self(rawValue: 1 << 1)
}

nonisolated struct LocalNotificationRequest: Equatable, Sendable {
    let identifier: String
    let title: String
    let body: String
    let userInfo: [String: String]
    let playsSound: Bool
}

nonisolated protocol UserNotificationCenterProviding: Sendable {
    func authorizationStatus() async -> LocalNotificationAuthorizationStatus
    func notificationRequestIdentifiers() async -> Set<String>
    func requestAuthorization(
        options: LocalNotificationAuthorizationOptions
    ) async throws -> Bool
    func add(_ request: LocalNotificationRequest) async throws
}

nonisolated final class SystemUserNotificationCenter:
    NSObject,
    UserNotificationCenterProviding,
    UNUserNotificationCenterDelegate,
    @unchecked Sendable
{
    static let shared = SystemUserNotificationCenter()

    private let center: UNUserNotificationCenter
    @MainActor private weak var navigationInbox:
        PriceAlertNotificationNavigationInbox?

    private init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
        center.delegate = self
    }

    @MainActor
    func installNavigationInbox(
        _ navigationInbox: PriceAlertNotificationNavigationInbox
    ) {
        self.navigationInbox = navigationInbox
    }

    func authorizationStatus() async -> LocalNotificationAuthorizationStatus {
        let settings = await center.notificationSettings()
        return switch settings.authorizationStatus {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .authorized: .authorized
        case .provisional: .provisional
        case .ephemeral: .ephemeral
        @unknown default: .denied
        }
    }

    func notificationRequestIdentifiers() async -> Set<String> {
        async let pendingRequests = center.pendingNotificationRequests()
        async let deliveredNotifications = center.deliveredNotifications()
        let (pending, delivered) = await (
            pendingRequests,
            deliveredNotifications
        )
        return Set(
            pending.map(\.identifier) +
            delivered.map(\.request.identifier)
        )
    }

    func requestAuthorization(
        options: LocalNotificationAuthorizationOptions
    ) async throws -> Bool {
        var systemOptions: UNAuthorizationOptions = []
        if options.contains(.alert) {
            systemOptions.insert(.alert)
        }
        if options.contains(.sound) {
            systemOptions.insert(.sound)
        }
        return try await center.requestAuthorization(options: systemOptions)
    }

    func add(_ request: LocalNotificationRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.userInfo = request.userInfo
        if request.playsSound {
            content.sound = .default
        }
        try await center.add(
            UNNotificationRequest(
                identifier: request.identifier,
                content: content,
                trigger: nil
            )
        )
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        guard notification.request.identifier.hasPrefix(
            PriceAlertNotificationIdentifier.prefix
        ) else {
            return []
        }
        return [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard let request = PriceAlertNotificationNavigationRequest(
            notificationIdentifier: response.notification.request.identifier,
            userInfo: response.notification.request.content.userInfo
        ) else {
            return
        }

        await navigationInbox?.receive(request)
    }
}
