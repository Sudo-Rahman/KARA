import Foundation
import SwiftData
import WidgetKit

nonisolated enum KaraAppBackgroundRefreshScheduleDecision:
    Equatable,
    Sendable
{
    case keepExisting
    case submit(earliestBeginDate: Date)
}

nonisolated struct KaraAppBackgroundRefreshSchedulePolicy: Sendable {
    let configuredWidgetInterval: TimeInterval
    let unconfiguredWidgetInterval: TimeInterval

    func decision(
        hasFrequentWork: Bool,
        pendingEarliestBeginDate: Date?,
        now: Date,
        forceReplaceExisting: Bool = false
    ) -> KaraAppBackgroundRefreshScheduleDecision {
        let interval = hasFrequentWork
            ? configuredWidgetInterval
            : unconfiguredWidgetInterval
        let desiredDate = now.addingTimeInterval(interval)

        if !forceReplaceExisting,
           let pendingEarliestBeginDate,
           pendingEarliestBeginDate <= desiredDate {
            return .keepExisting
        }
        return .submit(earliestBeginDate: desiredDate)
    }
}

/// Opportunistically refreshes the widget snapshot from the host application.
/// iOS controls execution time and frequency; the requested dates are not a
/// freshness guarantee.
@MainActor
enum KaraWidgetBestEffortBackgroundRefresh {
    static func hasConfiguredWidget() async -> Bool {
        do {
            return try await WidgetCenter.shared.currentConfigurations()
                .contains { $0.kind == KaraWidgetSnapshotPublisher.widgetKind }
        } catch {
            return false
        }
    }

    @discardableResult
    static func refreshSnapshot(modelContainer: ModelContainer) async throws -> Bool {
        try Task.checkCancellation()
        guard await hasConfiguredWidget() else { return false }
        try Task.checkCancellation()

        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Asset>(
            predicate: #Predicate { asset in
                asset.deletedAt == nil
            }
        )
        let assets = AssetCanonicalization
            .canonicalAssets(from: try context.fetch(descriptor))
            .sorted { $0.id.uuidString < $1.id.uuidString }
        let salesRepository = SalesRepository(context: context)
        let sales = try salesRepository.sales()
        let saleLines = try salesRepository.recordedSaleLines()
        let heldSnapshots = assets.compactMap { asset in
            let quantity = SalesLedger.heldQuantity(
                for: asset,
                recordedSaleLines: saleLines
            )
            return quantity > 0
                ? asset.portfolioSnapshot(heldQuantity: quantity)
                : nil
        }
        let originalSnapshots = assets.map(\.portfolioSnapshot)
        let salesByID = Dictionary(uniqueKeysWithValues: sales.map { ($0.id, $0) })
        let saleEvents = saleLines.compactMap { line in
            salesByID[line.saleID].map { sale in
                PortfolioSaleHistoryEvent(
                    id: line.id,
                    occurredAt: sale.soldAt,
                    soldQuantity: line.quantity,
                    assetSnapshotBeforeSale: line.portfolioSnapshotBeforeSale
                )
            }
        }

        try Task.checkCancellation()
        let requiredPairs = PortfolioValuationEngine
            .requiredSpotPairs(for: heldSnapshots)
            .union(MarketDataStore.defaultPairs)
        let marketStore = MarketDataStore.live()
        await marketStore.load(pairs: requiredPairs)
        try Task.checkCancellation()

        let quotes = Dictionary(
            uniqueKeysWithValues: MarketMetal.allCases.compactMap { metal in
                marketStore.quote(for: metal).map { (metal, $0) }
            }
        )
        // `lastRefreshAt` is an attempt timestamp, not the age of the data:
        // a failed network/App Attest refresh can leave the cache intact while
        // still updating that property. Use the oldest source timestamp that
        // actually contributed to this valuation instead.
        let asOf = quotes.values
            .map(\.sourceUpdatedAt)
            .min()
            ?? Date()
        let currentValuation = PortfolioValuationEngine().valuate(
            assets: heldSnapshots,
            market: marketStore.marketSnapshot,
            historyMonths: nil,
            asOf: asOf
        )
        let history = PortfolioHoldingHistoryEngine().history(
            assets: originalSnapshots,
            saleEvents: saleEvents,
            market: marketStore.marketSnapshot,
            asOf: asOf
        )
        let valuation = PortfolioValuation(
            totalEstimatedValueEUR: currentValuation.totalEstimatedValueEUR,
            totalPurchaseCostEUR: currentValuation.totalPurchaseCostEUR,
            totalGainEUR: currentValuation.totalGainEUR,
            gainPercentage: currentValuation.gainPercentage,
            assetValuations: currentValuation.assetValuations,
            metals: currentValuation.metals,
            categories: currentValuation.categories,
            coverage: currentValuation.coverage,
            history: history,
            historyUsesUnknownPurchaseDates: !history.isEmpty
                && originalSnapshots.contains { $0.purchaseDate == nil }
        )
        let input = KaraWidgetSnapshotPublicationInput(
            quotes: quotes,
            valuation: valuation,
            valuationAsOf: asOf,
            hidesSensitiveValues: PrivacyPreferences().hidesSensitiveValues,
            preservesExistingQuotes: false
        )

        guard KaraWidgetSnapshotPublisher.publish(input) else {
            throw KaraWidgetBackgroundRefreshError.publicationFailed
        }
        return true
    }
}

private nonisolated enum KaraWidgetBackgroundRefreshError: Error {
    case publicationFailed
}
