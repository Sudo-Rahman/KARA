import BackgroundTasks
import Foundation
import SwiftData
import WidgetKit

nonisolated enum PriceAlertBackgroundRefreshScheduleDecision:
    Equatable,
    Sendable
{
    case keepExisting
    case submit(earliestBeginDate: Date)
}

nonisolated struct PriceAlertBackgroundRefreshSchedulePolicy: Sendable {
    let refreshInterval: TimeInterval

    func decision(
        hasPendingRequest: Bool,
        now: Date
    ) -> PriceAlertBackgroundRefreshScheduleDecision {
        guard !hasPendingRequest else {
            return .keepExisting
        }
        return .submit(
            earliestBeginDate: now.addingTimeInterval(refreshInterval)
        )
    }
}

nonisolated enum PriceAlertValuationMonitoringDecision: Equatable, Sendable {
    case evaluate
    case retry
    case needsReview
}

nonisolated enum PriceAlertValuationMonitoringPolicy {
    static func decision(
        for status: PortfolioAssetValuationStatus
    ) -> PriceAlertValuationMonitoringDecision {
        switch status {
        case .valued:
            .evaluate
        case .missingEURQuote:
            .retry
        case .invalidQuantity,
             .missingMetal,
             .missingWeight,
             .invalidWeight,
             .missingPurity,
             .invalidPurity:
            .needsReview
        }
    }
}

/// Requests opportunistic price-alert checks. iOS decides whether and when
/// these best-effort refreshes run; this is not continuous monitoring.
@MainActor
enum PriceAlertBestEffortBackgroundRefresh {
    static let taskIdentifier =
        "com.karaprivate.KARA.price-alerts.best-effort-refresh"

    private static let schedulePolicy =
        KaraAppBackgroundRefreshSchedulePolicy(
            configuredWidgetInterval: 60 * 60,
            unconfiguredWidgetInterval: 12 * 60 * 60
        )
    private static let legacyWidgetTaskIdentifier =
        "com.karaprivate.KARA.widget.best-effort-refresh"
    private static var registrationResult: Bool?
    private static var modelContainer: ModelContainer?
    private static var scheduleTask: Task<Bool, Never>?
    private static var scheduleToken: UUID?

    /// Registers the launch handler once per process. Call during app startup,
    /// before the application finishes launching.
    @discardableResult
    static func register() -> Bool {
        if let registrationResult {
            return registrationResult
        }

        // Versions that shipped the widget scheduler separately may have a
        // pending request under this identifier. Migrate it into the single
        // app-wide refresh slot before registering the unified handler.
        BGTaskScheduler.shared.cancel(
            taskRequestWithIdentifier: legacyWidgetTaskIdentifier
        )

        let didRegister = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: .main
        ) { task in
            Task { @MainActor in
                guard let refreshTask = task as? BGAppRefreshTask else {
                    task.setTaskCompleted(success: false)
                    return
                }
                handle(refreshTask)
            }
        }
        registrationResult = didRegister
        return didRegister
    }

    /// Installs the one application-owned container used by both foreground
    /// views and the background refresh handler.
    ///
    /// Retaining it for the process lifetime prevents SwiftData from opening a
    /// second container against the same persistent store. This also preserves
    /// the in-memory container selected by UI-test launch arguments.
    static func install(modelContainer container: ModelContainer) {
        if let modelContainer {
            precondition(
                modelContainer === container,
                "KARA must use one ModelContainer for the process lifetime."
            )
            return
        }
        modelContainer = container
    }

    /// Ensures that the one app-wide refresh slot is pending. Price alerts and
    /// widget discovery share this request because iOS allows one pending
    /// `BGAppRefreshTaskRequest` per app, not one per identifier.
    ///
    /// A successful submission does not guarantee that iOS will run the
    /// refresh.
    @discardableResult
    static func schedule(
        hasFrequentPriceAlertWork: Bool = true,
        forceReplaceExisting: Bool = false,
        now: Date = Date()
    ) async -> Bool {
        if let scheduleTask {
            return await scheduleTask.value
        }

        let token = UUID()
        let task = Task { @MainActor in
            await performSchedule(
                hasFrequentPriceAlertWork: hasFrequentPriceAlertWork,
                forceReplaceExisting: forceReplaceExisting,
                now: now
            )
        }
        scheduleToken = token
        scheduleTask = task

        let result = await task.value
        if scheduleToken == token {
            scheduleTask = nil
            scheduleToken = nil
        }
        return result
    }

    private static func performSchedule(
        hasFrequentPriceAlertWork: Bool,
        forceReplaceExisting: Bool,
        now: Date
    ) async -> Bool {
        let hasConfiguredWidget =
            await KaraWidgetBestEffortBackgroundRefresh.hasConfiguredWidget()
        let pendingRequest = await pendingTaskRequest()
        guard !Task.isCancelled else { return false }

        switch schedulePolicy.decision(
            hasFrequentWork: hasFrequentPriceAlertWork || hasConfiguredWidget,
            pendingEarliestBeginDate: pendingRequest?.earliestBeginDate,
            now: now,
            forceReplaceExisting: forceReplaceExisting
        ) {
        case .keepExisting:
            return true
        case let .submit(earliestBeginDate):
            let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
            request.earliestBeginDate = earliestBeginDate
            do {
                // Resubmitting the same identifier replaces the pending
                // request atomically. Do not cancel first: a failed submit
                // must leave the old refresh in place.
                try BGTaskScheduler.shared.submit(request)
                return true
            } catch {
                return false
            }
        }
    }

    private static func pendingTaskRequest() async -> BGTaskRequest? {
        let identifier = taskIdentifier
        return await withCheckedContinuation { continuation in
            BGTaskScheduler.shared.getPendingTaskRequests { requests in
                continuation.resume(
                    returning: requests.first {
                        $0.identifier == identifier
                    }
                )
            }
        }
    }

    private static func handle(_ backgroundTask: BGAppRefreshTask) {
        let refresh = Task { @MainActor in
            // The executing request is no longer pending. Schedule its
            // successor before doing network or persistence work so expiration
            // cannot silently stop monitoring.
            _ = await schedule(hasFrequentPriceAlertWork: true)
            let hasActiveAlerts = try await refreshActiveAlerts()
            try Task.checkCancellation()
            let hasConfiguredWidget: Bool
            if let modelContainer {
                hasConfiguredWidget = try await
                    KaraWidgetBestEffortBackgroundRefresh.refreshSnapshot(
                        modelContainer: modelContainer
                    )
            } else {
                hasConfiguredWidget = false
            }
            return hasActiveAlerts || hasConfiguredWidget
        }
        backgroundTask.expirationHandler = {
            refresh.cancel()
        }

        Task { @MainActor in
            do {
                let hasFrequentWork = try await refresh.value
                _ = await schedule(
                    hasFrequentPriceAlertWork: hasFrequentWork,
                    forceReplaceExisting: true
                )
                backgroundTask.setTaskCompleted(success: true)
            } catch {
                // Missing persistence access, cancellation, and market failures
                // are retryable. Keep the successor requested at handler entry.
                _ = await schedule(hasFrequentPriceAlertWork: true)
                backgroundTask.setTaskCompleted(success: false)
            }
        }
    }

    /// Returns whether at least one alert still needs automatic monitoring.
    private static func refreshActiveAlerts() async throws -> Bool {
        try Task.checkCancellation()
        guard let modelContainer else {
            throw PriceAlertBackgroundRefreshError.missingModelContainer
        }

        let context = ModelContext(modelContainer)
        let alerts = try activeAlerts(in: context)
        let pendingNotificationsExist = try hasPendingNotifications(
            in: context
        )
        guard !alerts.isEmpty || pendingNotificationsExist else {
            return false
        }
        guard !alerts.isEmpty else {
            return try await retryPendingNotifications(in: context)
        }
        try Task.checkCancellation()

        let euroCode = MarketCurrency.eur.rawValue
        let alertsByAssetID = Dictionary(grouping: alerts, by: \.assetID)
        let salesRepository = SalesRepository(context: context)
        var heldSnapshots: [PortfolioAssetSnapshot] = []

        for (assetID, assetAlerts) in alertsByAssetID {
            try Task.checkCancellation()

            let monitorableAlerts = assetAlerts.filter { alert in
                guard alert.currencyCode == euroCode else {
                    alert.markNeedsReview()
                    return false
                }
                return true
            }
            guard !monitorableAlerts.isEmpty else { continue }

            guard let snapshot = try monitorableSnapshot(
                for: assetID,
                alerts: monitorableAlerts,
                in: context,
                salesRepository: salesRepository
            ) else {
                continue
            }

            heldSnapshots.append(snapshot)
        }

        try Task.checkCancellation()
        try context.save()

        let monitorableAlerts = alerts.filter { $0.status == .active }
        guard !monitorableAlerts.isEmpty else {
            return try await retryPendingNotifications(in: context)
        }

        // No asset context can be valued after the permanent invalid cases
        // above. Keep any remaining alert active and retry instead of silently
        // ending its monitoring.
        guard !heldSnapshots.isEmpty else { return true }

        let requiredPairs = PortfolioValuationEngine.requiredSpotPairs(
            for: heldSnapshots
        )
        let marketStore = MarketDataStore.live()
        await marketStore.load(pairs: requiredPairs)
        try Task.checkCancellation()

        let valuation = PortfolioValuationEngine().valuate(
            assets: heldSnapshots,
            market: marketStore.marketSnapshot,
            historyMonths: nil
        )
        var valuationsByAssetID: [UUID: PriceAlertAssetValuation] = [:]
        for assetValuation in valuation.assetValuations {
            switch PriceAlertValuationMonitoringPolicy.decision(
                for: assetValuation.status
            ) {
            case .evaluate:
                guard let amount = assetValuation.estimatedValueEUR else {
                    continue
                }
                valuationsByAssetID[assetValuation.assetID] =
                    PriceAlertAssetValuation(
                        assetID: assetValuation.assetID,
                        amount: amount,
                        currencyCode: euroCode
                    )
            case .retry:
                // A missing live/cached quote is transient. Leave the alert
                // active so the already-pending successor can try again.
                continue
            case .needsReview:
                alertsByAssetID[assetValuation.assetID]?
                    .filter { $0.status == .active }
                    .forEach { $0.markNeedsReview() }
            }
        }

        try await PriceAlertForegroundEvaluator().evaluateActiveAlerts(
            monitorableAlerts.filter { $0.status == .active },
            valuationsByAssetID: valuationsByAssetID,
            modelContext: context
        )
        try Task.checkCancellation()
        try context.save()
        let stillHasPendingNotifications = try hasPendingNotifications(
            in: context
        )
        return alerts.contains { $0.status == .active }
            || stillHasPendingNotifications
    }

    /// Shared, testable integrity boundary for background work. Fetching only
    /// raw `active` rows would allow a stale CloudKit duplicate to bypass a
    /// terminal canonical row with the same business identifier.
    static func activeAlerts(in context: ModelContext) throws -> [PriceAlert] {
        try SalesRepository(context: context)
            .alerts()
            .filter { $0.status == .active }
    }

    static func monitorableSnapshot(
        for assetID: UUID,
        alerts: [PriceAlert],
        in context: ModelContext
    ) throws -> PortfolioAssetSnapshot? {
        try monitorableSnapshot(
            for: assetID,
            alerts: alerts,
            in: context,
            salesRepository: SalesRepository(context: context)
        )
    }

    private static func monitorableSnapshot(
        for assetID: UUID,
        alerts: [PriceAlert],
        in context: ModelContext,
        salesRepository: SalesRepository
    ) throws -> PortfolioAssetSnapshot? {
        guard let asset = try canonicalAsset(
            for: assetID,
            in: context
        ) else {
            alerts.forEach { $0.markNeedsReview() }
            return nil
        }

        let heldQuantity = try salesRepository.heldQuantity(for: asset)
        guard heldQuantity > 0 else {
            alerts.forEach { $0.markNeedsReview() }
            return nil
        }
        return asset.portfolioSnapshot(heldQuantity: heldQuantity)
    }

    private static func canonicalAsset(
        for assetID: UUID,
        in context: ModelContext
    ) throws -> Asset? {
        let descriptor = FetchDescriptor<Asset>(
            predicate: #Predicate { asset in
                asset.id == assetID && asset.deletedAt == nil
            }
        )
        return AssetCanonicalization.preferredAsset(
            from: try context.fetch(descriptor)
        )
    }

    private static func retryPendingNotifications(
        in context: ModelContext
    ) async throws -> Bool {
        try await PriceAlertForegroundEvaluator().evaluateActiveAlerts(
            [],
            valuationsByAssetID: [:],
            modelContext: context
        )
        try Task.checkCancellation()
        return try hasPendingNotifications(in: context)
    }

    private static func hasPendingNotifications(
        in context: ModelContext
    ) throws -> Bool {
        var descriptor =
            FetchDescriptor<PriceAlertNotificationOutboxEntry>(
                predicate: #Predicate { entry in
                    entry.acknowledgedAt == nil
                }
            )
        descriptor.fetchLimit = 1
        let entries = try context.fetch(descriptor)
        return !entries.isEmpty
    }
}

private nonisolated enum PriceAlertBackgroundRefreshError: Error {
    case missingModelContainer
}
