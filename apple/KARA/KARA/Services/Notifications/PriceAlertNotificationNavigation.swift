import Foundation
import Observation

nonisolated struct PriceAlertNotificationNavigationRequest:
    Equatable,
    Hashable,
    Sendable
{
    let alertID: UUID
    let assetID: UUID?

    init(alertID: UUID, assetID: UUID? = nil) {
        self.alertID = alertID
        self.assetID = assetID
    }

    init?(
        notificationIdentifier: String,
        userInfo: [AnyHashable: Any]
    ) {
        guard let alertIDRawValue = userInfo["priceAlertID"] as? String,
        let alertID = UUID(uuidString: alertIDRawValue),
        notificationIdentifier ==
            PriceAlertNotificationIdentifier.make(alertID: alertID)
        else {
            return nil
        }

        self.alertID = alertID
        assetID = (userInfo["assetID"] as? String).flatMap(UUID.init(uuidString:))
    }
}

/// Retains a notification tap until the main app shell is ready to route it.
/// This matters when iOS launches KARA from a terminated state.
@MainActor
@Observable
final class PriceAlertNotificationNavigationInbox {
    private(set) var pendingRequest: PriceAlertNotificationNavigationRequest?

    func receive(_ request: PriceAlertNotificationNavigationRequest) {
        pendingRequest = request
    }

    @discardableResult
    func consume(_ request: PriceAlertNotificationNavigationRequest) -> Bool {
        guard pendingRequest == request else { return false }
        pendingRequest = nil
        return true
    }
}
