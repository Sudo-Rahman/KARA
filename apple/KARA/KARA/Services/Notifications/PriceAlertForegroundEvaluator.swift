import Foundation
import SwiftData

nonisolated struct PriceAlertAssetValuation: Equatable, Sendable {
    let assetID: UUID
    let amount: Decimal
    let currencyCode: String
}

nonisolated struct PriceAlertEvaluationSummary: Equatable, Sendable {
    let checkedCount: Int
    let triggeredCount: Int
    let deliveredNotificationCount: Int
    let skippedNotificationCount: Int
    let failedNotificationCount: Int
}

nonisolated enum PriceAlertEvaluationError: Error, Equatable {
    case missingModelContext
}

@MainActor
struct PriceAlertForegroundEvaluator {
    typealias SaveAction = @MainActor (ModelContext) throws -> Void

    private let notifications: any PriceAlertNotificationDelivering
    private let saveAction: SaveAction

    init(
        notifications: any PriceAlertNotificationDelivering =
            PriceAlertNotificationService(),
        saveAction: @escaping SaveAction = { try $0.save() }
    ) {
        self.notifications = notifications
        self.saveAction = saveAction
    }

    @discardableResult
    func evaluateActiveAlerts(
        _ alerts: [PriceAlert],
        valuationsByAssetID: [UUID: PriceAlertAssetValuation],
        at date: Date = Date(),
        modelContext explicitModelContext: ModelContext? = nil
    ) async throws -> PriceAlertEvaluationSummary {
        var checkedCount = 0
        var triggeredPayloads: [PriceAlertNotificationPayload] = []

        for alert in alerts where alert.status == .active {
            guard let valuation = valuationsByAssetID[alert.assetID],
                  valuation.assetID == alert.assetID,
                  valuation.currencyCode == alert.currencyCode
            else {
                continue
            }

            checkedCount += 1
            if alert.evaluate(currentValue: valuation.amount, at: date) {
                triggeredPayloads.append(
                    PriceAlertNotificationPayload(
                        alertID: alert.id,
                        assetID: alert.assetID
                    )
                )
            }
        }

        let modelContext =
            explicitModelContext ??
            alerts.lazy.compactMap { $0.modelContext }.first

        guard let modelContext else {
            guard triggeredPayloads.isEmpty else {
                throw PriceAlertEvaluationError.missingModelContext
            }
            return PriceAlertEvaluationSummary(
                checkedCount: checkedCount,
                triggeredCount: 0,
                deliveredNotificationCount: 0,
                skippedNotificationCount: 0,
                failedNotificationCount: 0
            )
        }

        let outbox = PriceAlertNotificationOutbox(modelContext: modelContext)
        try outbox.enqueueMissing(
            triggeredPayloads,
            createdAt: date
        )

        let pendingGroups = try outbox.pendingGroups()

        // This is the transaction boundary: the alert transition and its outbox
        // message must be durable before the external notification is attempted.
        if modelContext.hasChanges || !pendingGroups.isEmpty {
            try saveAction(modelContext)
        }

        var deliveredNotificationCount = 0
        var skippedNotificationCount = 0
        var failedNotificationCount = 0
        for group in pendingGroups {
            group.entries.forEach { $0.recordAttempt(at: date) }

            let delivery: PriceAlertNotificationDelivery
            do {
                delivery = try await notifications.deliverThresholdReached(
                    group.payload
                )
            } catch is CancellationError {
                try? saveAction(modelContext)
                throw CancellationError()
            } catch {
                failedNotificationCount += 1
                try? saveAction(modelContext)
                continue
            }

            switch delivery {
            case .delivered:
                deliveredNotificationCount += 1
                group.entries.forEach {
                    $0.acknowledge(outcome: .delivered, at: date)
                }
            case .authorizationNotDetermined:
                // Background work must never prompt. Keep the durable outbox
                // entry pending so a later foreground authorization can retry
                // the exact same notification identifier.
                skippedNotificationCount += 1
            case .denied:
                skippedNotificationCount += 1
                group.entries.forEach {
                    $0.acknowledge(
                        outcome: .permissionUnavailable,
                        at: date
                    )
                }
            }
            try saveAction(modelContext)
        }

        return PriceAlertEvaluationSummary(
            checkedCount: checkedCount,
            triggeredCount: triggeredPayloads.count,
            deliveredNotificationCount: deliveredNotificationCount,
            skippedNotificationCount: skippedNotificationCount,
            failedNotificationCount: failedNotificationCount
        )
    }
}

@MainActor
private struct PriceAlertNotificationOutbox {
    let modelContext: ModelContext

    func enqueueMissing(
        _ payloads: [PriceAlertNotificationPayload],
        createdAt: Date
    ) throws {
        let existingEntries = try modelContext.fetch(
            FetchDescriptor<PriceAlertNotificationOutboxEntry>()
        )
        var knownIdentifiers = Set(
            existingEntries.map(\.notificationIdentifier)
        )

        for payload in payloads {
            guard knownIdentifiers.insert(
                payload.notificationIdentifier
            ).inserted else {
                continue
            }
            modelContext.insert(
                PriceAlertNotificationOutboxEntry(
                    id: payload.alertID,
                    alertID: payload.alertID,
                    assetID: payload.assetID,
                    notificationIdentifier: payload.notificationIdentifier,
                    createdAt: createdAt
                )
            )
        }
    }

    func pendingGroups() throws -> [PendingNotificationGroup] {
        let pendingEntries = try modelContext.fetch(
            FetchDescriptor<PriceAlertNotificationOutboxEntry>()
        )
        .filter { !$0.isAcknowledged }

        return Dictionary(
            grouping: pendingEntries,
            by: \.notificationIdentifier
        )
        .values
        .compactMap { entries -> PendingNotificationGroup? in
            guard let first = entries.first else { return nil }
            return PendingNotificationGroup(
                payload: first.payload,
                entries: entries
            )
        }
        .sorted {
            let lhsDate = $0.entries.map(\.createdAt).min() ?? .distantFuture
            let rhsDate = $1.entries.map(\.createdAt).min() ?? .distantFuture
            if lhsDate != rhsDate {
                return lhsDate < rhsDate
            }
            return $0.payload.notificationIdentifier <
                $1.payload.notificationIdentifier
        }
    }
}

@MainActor
private struct PendingNotificationGroup {
    let payload: PriceAlertNotificationPayload
    let entries: [PriceAlertNotificationOutboxEntry]
}
