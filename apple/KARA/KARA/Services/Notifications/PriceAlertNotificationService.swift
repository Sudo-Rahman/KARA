import Foundation

nonisolated enum PriceAlertNotificationIdentifier {
    static let prefix = "price-alert-"

    static func make(alertID: UUID) -> String {
        "\(prefix)\(alertID.uuidString)"
    }
}

nonisolated struct PriceAlertNotificationCopy: Equatable, Sendable {
    let title: String
    let body: String

    static var localized: Self {
        Self(
            title: String(
                localized: LocalizedStringResource(
                    "Price target reached",
                    table: "PriceAlerts"
                )
            ),
            body: String(
                localized: LocalizedStringResource(
                    "Open KARA to view the details in your vault.",
                    table: "PriceAlerts"
                )
            )
        )
    }
}

nonisolated struct PriceAlertNotificationPayload: Equatable, Sendable {
    let alertID: UUID
    let assetID: UUID
    let notificationIdentifier: String

    init(
        alertID: UUID,
        assetID: UUID,
        notificationIdentifier: String? = nil
    ) {
        self.alertID = alertID
        self.assetID = assetID
        self.notificationIdentifier =
            notificationIdentifier ??
            PriceAlertNotificationIdentifier.make(alertID: alertID)
    }
}

nonisolated enum PriceAlertNotificationDelivery: Equatable, Sendable {
    case delivered
    case authorizationNotDetermined
    case denied
}

nonisolated protocol PriceAlertNotificationDelivering: Sendable {
    func deliverThresholdReached(
        _ payload: PriceAlertNotificationPayload
    ) async throws -> PriceAlertNotificationDelivery
}

nonisolated struct PriceAlertNotificationService: Sendable {
    private let center: any UserNotificationCenterProviding
    private let copy: PriceAlertNotificationCopy

    init(
        center: any UserNotificationCenterProviding =
            SystemUserNotificationCenter.shared,
        copy: PriceAlertNotificationCopy = .localized
    ) {
        self.center = center
        self.copy = copy
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func deliverThresholdReached(
        _ payload: PriceAlertNotificationPayload
    ) async throws -> PriceAlertNotificationDelivery {
        let existingIdentifiers =
            await center.notificationRequestIdentifiers()
        if existingIdentifiers.contains(payload.notificationIdentifier) {
            return .delivered
        }

        let status = await center.authorizationStatus()
        switch status {
        case .notDetermined:
            return .authorizationNotDetermined
        case .denied:
            return .denied
        case .authorized, .provisional, .ephemeral:
            break
        }

        try await center.add(
            LocalNotificationRequest(
                identifier: payload.notificationIdentifier,
                title: copy.title,
                body: copy.body,
                userInfo: [
                    "priceAlertID": payload.alertID.uuidString,
                    "assetID": payload.assetID.uuidString,
                ],
                playsSound: true
            )
        )
        return .delivered
    }
}

extension PriceAlertNotificationService: PriceAlertNotificationDelivering {}
