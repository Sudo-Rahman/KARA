import Foundation
import SwiftData
import Testing
@testable import KARA

@Suite("Local price-alert notifications")
@MainActor
struct PriceAlertNotificationTests {
    @Test("A price-alert notification response becomes a navigation request")
    func parsesNotificationNavigationRequest() throws {
        let alertID = UUID()
        let assetID = UUID()

        let request = try #require(
            PriceAlertNotificationNavigationRequest(
                notificationIdentifier: "price-alert-\(alertID.uuidString)",
                userInfo: [
                    "priceAlertID": alertID.uuidString,
                    "assetID": assetID.uuidString,
                ]
            )
        )

        #expect(request.alertID == alertID)
        #expect(request.assetID == assetID)
    }

    @Test("Unrelated and malformed notifications cannot change navigation")
    func rejectsInvalidNotificationNavigationRequests() {
        let alertID = UUID()

        #expect(
            PriceAlertNotificationNavigationRequest(
                notificationIdentifier: "another-feature",
                userInfo: ["priceAlertID": alertID.uuidString]
            ) == nil
        )
        #expect(
            PriceAlertNotificationNavigationRequest(
                notificationIdentifier: "price-alert-\(alertID.uuidString)",
                userInfo: ["priceAlertID": "invalid"]
            ) == nil
        )
        #expect(
            PriceAlertNotificationNavigationRequest(
                notificationIdentifier: "price-alert-\(UUID().uuidString)",
                userInfo: ["priceAlertID": alertID.uuidString]
            ) == nil
        )
    }

    @Test("A tapped notification remains pending until the app consumes it")
    func retainsNavigationRequestUntilConsumed() throws {
        let request = PriceAlertNotificationNavigationRequest(
            alertID: UUID(),
            assetID: UUID()
        )
        let inbox = PriceAlertNotificationNavigationInbox()

        inbox.receive(request)

        #expect(inbox.pendingRequest == request)
        #expect(inbox.consume(request))
        #expect(inbox.pendingRequest == nil)
        #expect(!inbox.consume(request))
    }

    @Test(
        "A notification response received off-main completes on the main thread"
    )
    func dispatchesNotificationResponseOnMainThread() async {
        let request = PriceAlertNotificationNavigationRequest(
            alertID: UUID(),
            assetID: UUID()
        )
        let inbox = PriceAlertNotificationNavigationInbox()
        let dispatcher = PriceAlertNotificationResponseDispatcher()
        dispatcher.installNavigationInbox(inbox)
        let probe = NotificationResponseCompletionProbe()

        await withCheckedContinuation { continuation in
            Task.detached {
                dispatcher.receive(request) {
                    probe.recordCompletion()
                    continuation.resume()
                }
            }
        }

        #expect(probe.completedOnMainThread)
        #expect(inbox.pendingRequest == request)
    }

    @Test("Requesting price-alert notifications delegates to the system boundary")
    func requestsAuthorization() async throws {
        let center = RecordingUserNotificationCenter(
            authorizationStatus: .notDetermined,
            authorizationResponse: true
        )
        let service = PriceAlertNotificationService(center: center)

        #expect(try await service.requestAuthorization())
        #expect(
            await center.authorizationRequests == [
                [.alert, .sound],
            ]
        )
    }

    @Test("A reached threshold is delivered immediately when notifications are authorized")
    func deliversAuthorizedThreshold() async throws {
        let alertID = UUID()
        let assetID = UUID()
        let center = RecordingUserNotificationCenter(
            authorizationStatus: .authorized
        )
        let service = PriceAlertNotificationService(
            center: center,
            copy: PriceAlertNotificationCopy(
                title: "Objectif de prix atteint",
                body:
                    "Ouvrez KARA pour consulter le détail dans votre coffre."
            )
        )
        let payload = PriceAlertNotificationPayload(
            alertID: alertID,
            assetID: assetID
        )

        #expect(
            try await service.deliverThresholdReached(payload) == .delivered
        )
        let request = try #require(await center.requests.first)
        #expect(request.identifier == "price-alert-\(alertID.uuidString)")
        #expect(request.title == "Objectif de prix atteint")
        #expect(
            request.body ==
                "Ouvrez KARA pour consulter le détail dans votre coffre."
        )
        #expect(request.userInfo["priceAlertID"] == alertID.uuidString)
        #expect(request.userInfo["assetID"] == assetID.uuidString)
        #expect(request.playsSound)
    }

    @Test("Retrying a delivered identifier does not add a duplicate system notification")
    func systemDeliveryIsIdempotent() async throws {
        let center = RecordingUserNotificationCenter(
            authorizationStatus: .authorized
        )
        let service = PriceAlertNotificationService(center: center)
        let payload = PriceAlertNotificationPayload(
            alertID: UUID(),
            assetID: UUID()
        )

        #expect(
            try await service.deliverThresholdReached(payload) == .delivered
        )
        #expect(
            try await service.deliverThresholdReached(payload) == .delivered
        )
        #expect(await center.requests.count == 1)
    }

    @Test("Delivery keeps a retryable result while permission is undetermined")
    func preservesDeliveryWhilePermissionIsUndetermined() async throws {
        let center = RecordingUserNotificationCenter(
            authorizationStatus: .notDetermined
        )
        let service = PriceAlertNotificationService(center: center)

        let result = try await service.deliverThresholdReached(
            PriceAlertNotificationPayload(
                alertID: UUID(),
                assetID: UUID()
            )
        )

        #expect(result == .authorizationNotDetermined)
        #expect(await center.requests.isEmpty)
        #expect(await center.authorizationRequests.isEmpty)
    }

    @Test("Delivery reports a denied notification permission without prompting")
    func skipsDeliveryWhenPermissionIsDenied() async throws {
        let center = RecordingUserNotificationCenter(
            authorizationStatus: .denied
        )
        let service = PriceAlertNotificationService(center: center)

        let result = try await service.deliverThresholdReached(
            PriceAlertNotificationPayload(
                alertID: UUID(),
                assetID: UUID()
            )
        )

        #expect(result == .denied)
        #expect(await center.requests.isEmpty)
        #expect(await center.authorizationRequests.isEmpty)
    }

    @Test("A foreground refresh evaluates active alerts and notifies only a newly reached threshold")
    func evaluatesActiveAlertsOnRefresh() async throws {
        let context = try makeContext()
        let assetID = UUID()
        let reached = try PriceAlert.make(
            assetID: assetID,
            targetValue: 3_000,
            currentValue: 2_800,
            currencyCode: "EUR"
        )
        let unreached = try PriceAlert.make(
            assetID: assetID,
            targetValue: 4_000,
            currentValue: 2_800,
            currencyCode: "EUR"
        )
        let paused = try PriceAlert.make(
            assetID: assetID,
            targetValue: 2_500,
            currentValue: 2_800,
            currencyCode: "EUR"
        )
        paused.status = .paused
        context.insert(reached)
        context.insert(unreached)
        context.insert(paused)
        try context.save()
        let notifications = RecordingPriceAlertNotificationDelivery()
        let evaluator = PriceAlertForegroundEvaluator(
            notifications: notifications
        )
        let checkedAt = Date(timeIntervalSince1970: 1_750_000_000)

        let summary = try await evaluator.evaluateActiveAlerts(
            [reached, unreached, paused],
            valuationsByAssetID: [
                assetID: PriceAlertAssetValuation(
                    assetID: assetID,
                    amount: 3_000,
                    currencyCode: "EUR"
                ),
            ],
            at: checkedAt
        )

        #expect(summary.checkedCount == 2)
        #expect(summary.triggeredCount == 1)
        #expect(summary.deliveredNotificationCount == 1)
        #expect(summary.skippedNotificationCount == 0)
        #expect(summary.failedNotificationCount == 0)
        #expect(reached.status == .triggered)
        #expect(reached.lastCheckedAt == checkedAt)
        #expect(unreached.status == .active)
        #expect(unreached.lastCheckedAt == checkedAt)
        #expect(paused.status == .paused)
        #expect(paused.lastCheckedAt == nil)
        let repeatedSummary = try await evaluator.evaluateActiveAlerts(
            [reached],
            valuationsByAssetID: [
                assetID: PriceAlertAssetValuation(
                    assetID: assetID,
                    amount: 3_100,
                    currencyCode: "EUR"
                ),
            ],
            at: checkedAt.addingTimeInterval(60)
        )
        #expect(repeatedSummary.checkedCount == 0)
        #expect(repeatedSummary.triggeredCount == 0)
        #expect(await notifications.payloads == [
            PriceAlertNotificationPayload(
                alertID: reached.id,
                assetID: assetID
            ),
        ])
        let outboxEntries = try context.fetch(
            FetchDescriptor<PriceAlertNotificationOutboxEntry>()
        )
        let outboxEntry = try #require(outboxEntries.first)
        #expect(outboxEntry.isAcknowledged)
        #expect(outboxEntry.deliveryOutcome == .delivered)
        #expect(outboxEntry.attemptCount == 1)
    }

    @Test("A reached alert stays triggered when notifications are unavailable")
    func recordsTriggerWithoutNotificationPermission() async throws {
        let context = try makeContext()
        let assetID = UUID()
        let alert = try PriceAlert.make(
            assetID: assetID,
            targetValue: 3_000,
            currentValue: 2_800,
            currencyCode: "EUR"
        )
        context.insert(alert)
        try context.save()
        let notifications = RecordingPriceAlertNotificationDelivery(
            result: .denied
        )
        let evaluator = PriceAlertForegroundEvaluator(
            notifications: notifications
        )
        let checkedAt = Date(timeIntervalSince1970: 1_750_000_100)

        let summary = try await evaluator.evaluateActiveAlerts(
            [alert],
            valuationsByAssetID: [
                assetID: PriceAlertAssetValuation(
                    assetID: assetID,
                    amount: 3_000,
                    currencyCode: "EUR"
                ),
            ],
            at: checkedAt
        )

        #expect(alert.status == .triggered)
        #expect(alert.lastCheckedAt == checkedAt)
        #expect(summary.triggeredCount == 1)
        #expect(summary.deliveredNotificationCount == 0)
        #expect(summary.skippedNotificationCount == 1)
        #expect(summary.failedNotificationCount == 0)

        let repeatedSummary = try await evaluator.evaluateActiveAlerts(
            [alert],
            valuationsByAssetID: [:],
            at: checkedAt.addingTimeInterval(60)
        )
        #expect(repeatedSummary.skippedNotificationCount == 0)
        #expect(await notifications.payloads.count == 1)

        let outboxEntries = try context.fetch(
            FetchDescriptor<PriceAlertNotificationOutboxEntry>()
        )
        let outboxEntry = try #require(outboxEntries.first)
        #expect(outboxEntry.isAcknowledged)
        #expect(outboxEntry.deliveryOutcome == .permissionUnavailable)
        #expect(outboxEntry.attemptCount == 1)
    }

    @Test(
        "An undetermined permission keeps the outbox pending until a later authorized retry"
    )
    func retriesAfterPermissionBecomesDetermined() async throws {
        let context = try makeContext()
        let assetID = UUID()
        let alert = try PriceAlert.make(
            assetID: assetID,
            targetValue: 3_000,
            currentValue: 2_800,
            currencyCode: "EUR"
        )
        context.insert(alert)
        try context.save()
        let notifications = SequencedPermissionNotificationDelivery(
            outcomes: [.authorizationNotDetermined, .delivered]
        )
        let evaluator = PriceAlertForegroundEvaluator(
            notifications: notifications
        )

        let firstSummary = try await evaluator.evaluateActiveAlerts(
            [alert],
            valuationsByAssetID: [
                assetID: PriceAlertAssetValuation(
                    assetID: assetID,
                    amount: 3_000,
                    currencyCode: "EUR"
                ),
            ]
        )

        #expect(firstSummary.triggeredCount == 1)
        #expect(firstSummary.skippedNotificationCount == 1)
        var entry = try #require(
            try context.fetch(
                FetchDescriptor<PriceAlertNotificationOutboxEntry>()
            ).first
        )
        #expect(!entry.isAcknowledged)
        #expect(entry.attemptCount == 1)

        let retrySummary = try await evaluator.evaluateActiveAlerts(
            [alert],
            valuationsByAssetID: [:]
        )

        #expect(retrySummary.triggeredCount == 0)
        #expect(retrySummary.deliveredNotificationCount == 1)
        entry = try #require(
            try context.fetch(
                FetchDescriptor<PriceAlertNotificationOutboxEntry>()
            ).first
        )
        #expect(entry.isAcknowledged)
        #expect(entry.deliveryOutcome == .delivered)
        #expect(entry.attemptCount == 2)
        #expect(await notifications.payloads.count == 2)
    }

    @Test(
        "A failed delivery stays pending, retries with the same identifier, and stops after acknowledgement"
    )
    func retriesPendingDeliveryIdempotently() async throws {
        let context = try makeContext()
        let assetID = UUID()
        let alert = try PriceAlert.make(
            assetID: assetID,
            targetValue: 3_000,
            currentValue: 2_800,
            currencyCode: "EUR"
        )
        context.insert(alert)
        try context.save()
        let notifications = SequencedPriceAlertNotificationDelivery(
            outcomes: [.failure, .delivered]
        )
        let evaluator = PriceAlertForegroundEvaluator(
            notifications: notifications
        )

        let firstSummary = try await evaluator.evaluateActiveAlerts(
            [alert],
            valuationsByAssetID: [
                assetID: PriceAlertAssetValuation(
                    assetID: assetID,
                    amount: 3_000,
                    currencyCode: "EUR"
                ),
            ]
        )

        #expect(firstSummary.triggeredCount == 1)
        #expect(firstSummary.failedNotificationCount == 1)
        let retryContext = ModelContext(context.container)
        var entries = try retryContext.fetch(
            FetchDescriptor<PriceAlertNotificationOutboxEntry>()
        )
        var entry = try #require(entries.first)
        #expect(!entry.isAcknowledged)
        #expect(entry.attemptCount == 1)
        let persistedAlert = try #require(
            try retryContext.fetch(FetchDescriptor<PriceAlert>()).first
        )

        let retrySummary = try await evaluator.evaluateActiveAlerts(
            [persistedAlert],
            valuationsByAssetID: [:]
        )

        #expect(retrySummary.triggeredCount == 0)
        #expect(retrySummary.deliveredNotificationCount == 1)
        let payloadsAfterRetry = await notifications.payloads
        #expect(payloadsAfterRetry.count == 2)
        #expect(
            payloadsAfterRetry[0].notificationIdentifier ==
                payloadsAfterRetry[1].notificationIdentifier
        )
        #expect(
            payloadsAfterRetry[0].notificationIdentifier ==
                PriceAlertNotificationIdentifier.make(alertID: alert.id)
        )

        let acknowledgedContext = ModelContext(context.container)
        entries = try acknowledgedContext.fetch(
            FetchDescriptor<PriceAlertNotificationOutboxEntry>()
        )
        entry = try #require(entries.first)
        #expect(entry.isAcknowledged)
        #expect(entry.deliveryOutcome == .delivered)
        #expect(entry.attemptCount == 2)

        let acknowledgedAlert = try #require(
            try acknowledgedContext.fetch(FetchDescriptor<PriceAlert>()).first
        )
        _ = try await evaluator.evaluateActiveAlerts(
            [acknowledgedAlert],
            valuationsByAssetID: [:]
        )
        #expect(await notifications.payloads.count == 2)
    }

    @Test("No notification is attempted before the trigger and outbox commit succeeds")
    func persistsBeforeExternalDelivery() async throws {
        let context = try makeContext()
        let assetID = UUID()
        let alert = try PriceAlert.make(
            assetID: assetID,
            targetValue: 3_000,
            currentValue: 2_800,
            currencyCode: "EUR"
        )
        context.insert(alert)
        try context.save()
        let notifications = RecordingPriceAlertNotificationDelivery()
        let saveGate = FailingOutboxSaveGate(failingCall: 1)
        let evaluator = PriceAlertForegroundEvaluator(
            notifications: notifications,
            saveAction: saveGate.save
        )

        do {
            _ = try await evaluator.evaluateActiveAlerts(
                [alert],
                valuationsByAssetID: [
                    assetID: PriceAlertAssetValuation(
                        assetID: assetID,
                        amount: 3_000,
                        currencyCode: "EUR"
                    ),
                ]
            )
            Issue.record("The outbox save should have failed")
        } catch is OutboxSaveTestError {
            // Expected: the external boundary must not have been reached.
        }

        #expect(await notifications.payloads.isEmpty)

        let retryEvaluator = PriceAlertForegroundEvaluator(
            notifications: notifications
        )
        let retrySummary = try await retryEvaluator.evaluateActiveAlerts(
            [alert],
            valuationsByAssetID: [:]
        )
        #expect(retrySummary.deliveredNotificationCount == 1)
        #expect(await notifications.payloads.count == 1)
    }

    @Test("An acknowledgement save failure retries without duplicating the system notification")
    func acknowledgementSaveFailureIsIdempotent() async throws {
        let context = try makeContext()
        let assetID = UUID()
        let alert = try PriceAlert.make(
            assetID: assetID,
            targetValue: 3_000,
            currentValue: 2_800,
            currencyCode: "EUR"
        )
        context.insert(alert)
        try context.save()
        let center = RecordingUserNotificationCenter(
            authorizationStatus: .authorized
        )
        let service = PriceAlertNotificationService(center: center)
        let saveGate = FailingOutboxSaveGate(failingCall: 2)
        let evaluator = PriceAlertForegroundEvaluator(
            notifications: service,
            saveAction: saveGate.save
        )

        do {
            _ = try await evaluator.evaluateActiveAlerts(
                [alert],
                valuationsByAssetID: [
                    assetID: PriceAlertAssetValuation(
                        assetID: assetID,
                        amount: 3_000,
                        currencyCode: "EUR"
                    ),
                ]
            )
            Issue.record("The acknowledgement save should have failed")
        } catch is OutboxSaveTestError {
            // Expected after the system notification has been added once.
        }
        #expect(await center.requests.count == 1)

        let restartedContext = ModelContext(context.container)
        let restartedAlert = try #require(
            try restartedContext.fetch(FetchDescriptor<PriceAlert>()).first
        )
        let retryEvaluator = PriceAlertForegroundEvaluator(
            notifications: service
        )
        let retrySummary = try await retryEvaluator.evaluateActiveAlerts(
            [restartedAlert],
            valuationsByAssetID: [:]
        )

        #expect(retrySummary.deliveredNotificationCount == 1)
        #expect(await center.requests.count == 1)
        let acknowledgedEntry = try #require(
            try restartedContext.fetch(
                FetchDescriptor<PriceAlertNotificationOutboxEntry>()
            ).first
        )
        #expect(acknowledgedEntry.isAcknowledged)
        #expect(acknowledgedEntry.deliveryOutcome == .delivered)
    }

    private func makeContext() throws -> ModelContext {
        let container = try KaraModelContainerFactory.make(
            arguments: [KaraModelContainerFactory.inMemoryLaunchArgument],
            environment: [:]
        )
        return ModelContext(container)
    }
}

private actor RecordingUserNotificationCenter: UserNotificationCenterProviding {
    private let status: LocalNotificationAuthorizationStatus
    private let authorizationResponse: Bool
    private(set) var authorizationRequests:
        [LocalNotificationAuthorizationOptions] = []
    private(set) var requests: [LocalNotificationRequest] = []

    init(
        authorizationStatus: LocalNotificationAuthorizationStatus,
        authorizationResponse: Bool = false
    ) {
        status = authorizationStatus
        self.authorizationResponse = authorizationResponse
    }

    func authorizationStatus() async -> LocalNotificationAuthorizationStatus {
        status
    }

    func notificationRequestIdentifiers() async -> Set<String> {
        Set(requests.map(\.identifier))
    }

    func requestAuthorization(
        options: LocalNotificationAuthorizationOptions
    ) async throws -> Bool {
        authorizationRequests.append(options)
        return authorizationResponse
    }

    func add(_ request: LocalNotificationRequest) async throws {
        requests.append(request)
    }
}

private actor RecordingPriceAlertNotificationDelivery:
    PriceAlertNotificationDelivering
{
    private let result: PriceAlertNotificationDelivery
    private(set) var payloads: [PriceAlertNotificationPayload] = []

    init(result: PriceAlertNotificationDelivery = .delivered) {
        self.result = result
    }

    func deliverThresholdReached(
        _ payload: PriceAlertNotificationPayload
    ) async throws -> PriceAlertNotificationDelivery {
        payloads.append(payload)
        return result
    }
}

nonisolated private final class NotificationResponseCompletionProbe:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var completionThreadWasMain = false

    var completedOnMainThread: Bool {
        lock.withLock { completionThreadWasMain }
    }

    func recordCompletion() {
        lock.withLock {
            completionThreadWasMain = Thread.isMainThread
        }
    }
}

private enum SequencedNotificationOutcome: Sendable {
    case failure
    case delivered
}

private enum SequencedNotificationError: Error {
    case unavailable
}

private actor SequencedPriceAlertNotificationDelivery:
    PriceAlertNotificationDelivering
{
    private var outcomes: [SequencedNotificationOutcome]
    private(set) var payloads: [PriceAlertNotificationPayload] = []

    init(outcomes: [SequencedNotificationOutcome]) {
        self.outcomes = outcomes
    }

    func deliverThresholdReached(
        _ payload: PriceAlertNotificationPayload
    ) async throws -> PriceAlertNotificationDelivery {
        payloads.append(payload)
        let outcome = outcomes.isEmpty ? .delivered : outcomes.removeFirst()
        switch outcome {
        case .failure:
            throw SequencedNotificationError.unavailable
        case .delivered:
            return .delivered
        }
    }
}

private actor SequencedPermissionNotificationDelivery:
    PriceAlertNotificationDelivering
{
    private var outcomes: [PriceAlertNotificationDelivery]
    private(set) var payloads: [PriceAlertNotificationPayload] = []

    init(outcomes: [PriceAlertNotificationDelivery]) {
        self.outcomes = outcomes
    }

    func deliverThresholdReached(
        _ payload: PriceAlertNotificationPayload
    ) async throws -> PriceAlertNotificationDelivery {
        payloads.append(payload)
        return outcomes.isEmpty ? .delivered : outcomes.removeFirst()
    }
}

private enum OutboxSaveTestError: Error {
    case unavailable
}

@MainActor
private final class FailingOutboxSaveGate {
    private let failingCall: Int
    private var callCount = 0

    init(failingCall: Int) {
        self.failingCall = failingCall
    }

    func save(_ context: ModelContext) throws {
        callCount += 1
        if callCount == failingCall {
            throw OutboxSaveTestError.unavailable
        }
        try context.save()
    }
}
