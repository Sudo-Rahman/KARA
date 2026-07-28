import Foundation
import SwiftData

nonisolated enum PriceAlertNotificationDeliveryOutcome:
    String,
    Codable,
    Sendable
{
    case delivered
    case permissionUnavailable
}

@Model
final class PriceAlertNotificationOutboxEntry {
    var id: UUID = UUID()
    var alertID: UUID = UUID()
    var assetID: UUID = UUID()
    var notificationIdentifier: String = ""
    var createdAt: Date = Date()
    var lastAttemptAt: Date?
    var attemptCount: Int = 0
    var acknowledgedAt: Date?
    var deliveryOutcomeRawValue: String = ""

    var isAcknowledged: Bool {
        acknowledgedAt != nil
    }

    var deliveryOutcome: PriceAlertNotificationDeliveryOutcome? {
        get {
            PriceAlertNotificationDeliveryOutcome(
                rawValue: deliveryOutcomeRawValue
            )
        }
        set {
            deliveryOutcomeRawValue = newValue?.rawValue ?? ""
        }
    }

    var payload: PriceAlertNotificationPayload {
        PriceAlertNotificationPayload(
            alertID: alertID,
            assetID: assetID,
            notificationIdentifier: notificationIdentifier
        )
    }

    init(
        id: UUID,
        alertID: UUID,
        assetID: UUID,
        notificationIdentifier: String,
        createdAt: Date
    ) {
        self.id = id
        self.alertID = alertID
        self.assetID = assetID
        self.notificationIdentifier = notificationIdentifier
        self.createdAt = createdAt
    }

    func recordAttempt(at date: Date) {
        attemptCount += 1
        lastAttemptAt = date
    }

    func acknowledge(
        outcome: PriceAlertNotificationDeliveryOutcome,
        at date: Date
    ) {
        deliveryOutcome = outcome
        acknowledgedAt = date
    }
}
