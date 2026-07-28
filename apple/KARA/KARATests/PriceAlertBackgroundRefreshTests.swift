import Foundation
import SwiftData
import Testing
@testable import KARA

@Suite("Best-effort price-alert refresh scheduling")
@MainActor
struct PriceAlertBackgroundRefreshTests {
    @Test("A refresh is requested one interval from now when none is pending")
    func requestsRefreshWhenNoneIsPending() {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let policy = PriceAlertBackgroundRefreshSchedulePolicy(
            refreshInterval: 60 * 60
        )

        #expect(
            policy.decision(
                hasPendingRequest: false,
                now: now
            ) == .submit(
                earliestBeginDate: now.addingTimeInterval(60 * 60)
            )
        )
    }

    @Test("An existing request is preserved instead of moving its deadline")
    func preservesExistingRequest() {
        let policy = PriceAlertBackgroundRefreshSchedulePolicy(
            refreshInterval: 60 * 60
        )

        #expect(
            policy.decision(
                hasPendingRequest: true,
                now: Date(timeIntervalSince1970: 1_750_000_000)
            ) == .keepExisting
        )
    }

    @Test(
        "Only permanently invalid asset data asks the user to review an alert",
        arguments: [
            (
                PortfolioAssetValuationStatus.valued,
                PriceAlertValuationMonitoringDecision.evaluate
            ),
            (
                PortfolioAssetValuationStatus.missingEURQuote,
                PriceAlertValuationMonitoringDecision.retry
            ),
            (
                PortfolioAssetValuationStatus.missingMetal,
                PriceAlertValuationMonitoringDecision.needsReview
            ),
            (
                PortfolioAssetValuationStatus.missingWeight,
                PriceAlertValuationMonitoringDecision.needsReview
            ),
            (
                PortfolioAssetValuationStatus.invalidWeight,
                PriceAlertValuationMonitoringDecision.needsReview
            ),
            (
                PortfolioAssetValuationStatus.missingPurity,
                PriceAlertValuationMonitoringDecision.needsReview
            ),
            (
                PortfolioAssetValuationStatus.invalidPurity,
                PriceAlertValuationMonitoringDecision.needsReview
            ),
            (
                PortfolioAssetValuationStatus.invalidQuantity,
                PriceAlertValuationMonitoringDecision.needsReview
            ),
        ]
    )
    func classifiesValuationAvailability(
        status: PortfolioAssetValuationStatus,
        expectedDecision: PriceAlertValuationMonitoringDecision
    ) {
        #expect(
            PriceAlertValuationMonitoringPolicy.decision(for: status)
                == expectedDecision
        )
    }

    @Test("Background monitoring selects only canonical active alerts")
    func selectsCanonicalActiveAlerts() throws {
        let container = try KaraModelContainerFactory.make(
            arguments: [KaraModelContainerFactory.inMemoryLaunchArgument],
            environment: [:]
        )
        let context = ModelContext(container)
        let duplicatedID = UUID()
        let assetID = UUID()
        let cancelled = PriceAlert(
            id: duplicatedID,
            assetID: assetID,
            targetValueMinorUnits: 300_000,
            currencyCode: "EUR",
            direction: .above,
            status: .cancelled,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let newerActiveDuplicate = PriceAlert(
            id: duplicatedID,
            assetID: assetID,
            targetValueMinorUnits: 300_000,
            currencyCode: "EUR",
            direction: .above,
            status: .active,
            createdAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
        let genuinelyActive = PriceAlert(
            assetID: UUID(),
            targetValueMinorUnits: 200_000,
            currencyCode: "EUR",
            direction: .below,
            status: .active
        )
        context.insert(cancelled)
        context.insert(newerActiveDuplicate)
        context.insert(genuinelyActive)
        try context.save()

        let selected = try PriceAlertBestEffortBackgroundRefresh.activeAlerts(
            in: context
        )

        #expect(selected.map(\.id) == [genuinelyActive.id])
    }

    @Test(
        "A stale duplicate asset cannot keep a fully sold holding monitorable"
    )
    func canonicalAssetPreventsMonitoringAfterFullSale() throws {
        let container = try KaraModelContainerFactory.make(
            arguments: [KaraModelContainerFactory.inMemoryLaunchArgument],
            environment: [:]
        )
        let context = ModelContext(container)
        let assetID = UUID()
        let staleDuplicate = Asset(
            id: assetID,
            name: "Lingotin obsolète",
            category: .bar,
            quantity: 2,
            metal: .gold,
            weightGrams: 10,
            finenessPermille: 999.9,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_001)
        )
        let canonicalAsset = Asset(
            id: assetID,
            name: "Lingotin canonique",
            category: .bar,
            quantity: 1,
            metal: .gold,
            weightGrams: 10,
            finenessPermille: 999.9,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
        context.insert(staleDuplicate)
        context.insert(canonicalAsset)
        try context.save()

        _ = try SalesRepository(context: context).recordSale(
            asset: canonicalAsset,
            quantity: 1,
            grossAmount: 700
        )
        let alert = try SalesRepository(context: context).createAlert(
            assetID: assetID,
            targetValue: 800,
            currentValue: 700,
            currencyCode: "EUR"
        )

        let snapshot =
            try PriceAlertBestEffortBackgroundRefresh.monitorableSnapshot(
                for: assetID,
                alerts: [alert],
                in: context
            )

        #expect(snapshot == nil)
        #expect(alert.status == .needsReview)
        #expect(!alert.evaluate(currentValue: 900))
    }

    @Test("Asset canonicalization has a deterministic tie-break")
    func canonicalAssetTieBreakIsOrderIndependent() {
        let id = UUID()
        let timestamp = Date(timeIntervalSince1970: 1_700_000_000)
        let preferred = Asset(
            id: id,
            name: "Alpha",
            category: .coin,
            createdAt: timestamp,
            updatedAt: timestamp
        )
        let other = Asset(
            id: id,
            name: "Zulu",
            category: .coin,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        let firstOrder = AssetCanonicalization.preferredAsset(
            from: [other, preferred]
        )
        let reversedOrder = AssetCanonicalization.preferredAsset(
            from: [preferred, other]
        )

        #expect(firstOrder === reversedOrder)
        #expect(
            AssetCanonicalization.canonicalAssets(
                from: [other, preferred]
            ).count == 1
        )
    }
}
