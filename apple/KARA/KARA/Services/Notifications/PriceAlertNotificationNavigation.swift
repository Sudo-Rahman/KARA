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

/// Bridges the notification-center callback onto the UI actor. UIKit may
/// invoke its delegate on a cooperative queue, including during a cold launch.
/// Both the observable mutation and the system completion must happen on the
/// main thread because SwiftUI synchronizes scene activation at that boundary.
nonisolated final class PriceAlertNotificationResponseDispatcher:
    @unchecked Sendable
{
    @MainActor private weak var navigationInbox:
        PriceAlertNotificationNavigationInbox?

    @MainActor
    func installNavigationInbox(
        _ navigationInbox: PriceAlertNotificationNavigationInbox
    ) {
        self.navigationInbox = navigationInbox
    }

    func receive(
        _ request: PriceAlertNotificationNavigationRequest?,
        completion: @escaping @Sendable () -> Void
    ) {
        Task { @MainActor [weak self] in
            if let request {
                self?.navigationInbox?.receive(request)
            }
            completion()
        }
    }
}
