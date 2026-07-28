import SwiftData
import SwiftUI

struct AppShellView: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AIFormAutofillPreferences.self) private var analysisPreferences
    @Environment(PriceAlertNotificationNavigationInbox.self)
    private var priceAlertNotificationNavigationInbox

    @Query(
        filter: #Predicate<Asset> { $0.deletedAt == nil },
        sort: \Asset.createdAt,
        order: .reverse
    ) private var assets: [Asset]
    @Query(sort: \AssetAttachment.createdAt, order: .reverse) private var attachments: [AssetAttachment]
    @Query(sort: \Sale.soldAt, order: .reverse) private var sales: [Sale]
    @Query private var saleLines: [SaleLine]
    @Query(sort: \PriceAlert.createdAt, order: .reverse) private var alerts: [PriceAlert]
    @Query(
        filter: #Predicate<PriceAlertNotificationOutboxEntry> {
            $0.acknowledgedAt == nil
        }
    ) private var pendingPriceAlertNotifications:
        [PriceAlertNotificationOutboxEntry]

    private let analyzer: any AssetAnalyzing = RemoteAssetAnalysisService()
    private let valuationEngine = PortfolioValuationEngine()
    private let priceAlertEvaluator = PriceAlertForegroundEvaluator()

    @State private var router = AppRouter()
    @State private var marketStore = MarketDataStore.live()
    @State private var valuationCache = PortfolioValuationCache()
    @State private var valuationAsOf = Date()

    var body: some View {
        @Bindable var router = router
        let valuation = portfolioValuation
        let assets = heldAssets
        let attachments = heldAttachments
        let sales = canonicalSales
        let alerts = canonicalAlerts

        TabView(selection: $router.selectedTab) {
            Tab(value: .vault) {
                NavigationStack(path: $router.path) {
                    VaultDashboardView(
                        assets: assets,
                        attachments: attachments,
                        valuation: valuation,
                        metalQuotes: metalQuotes,
                        isRefreshing: marketStore.isRefreshing,
                        isUsingCachedMarketData: marketStore.isUsingCachedData,
                        refresh: refreshMarket
                    )
                    .navigationDestination(for: AppRoute.self) { route in
                        destination(for: route, portfolioValuation: valuation)
                    }
                }
            } label: {
                Label("tabs.vault", systemImage: "lock.fill")
                    .accessibilityIdentifier("tab.vault")
            }

            Tab(value: .analysis) {
                NavigationStack {
                    AnalysisDashboardView(
                        valuation: valuation,
                        storageLocationsByAssetID: storageLocationsByAssetID,
                        sales: analyticsSales,
                        valuationAsOf: valuationAsOf,
                        isRefreshing: marketStore.isRefreshing,
                        isUsingCachedMarketData: marketStore.isUsingCachedData,
                        refresh: refreshMarket
                    )
                }
            } label: {
                Label("tabs.analysis", systemImage: "chart.xyaxis.line")
                    .accessibilityIdentifier("tab.analysis")
            }

            Tab(value: .sale) {
                NavigationStack(path: $router.salesPath) {
                    SalesDashboardView(
                        assets: assets,
                        assetCatalog: canonicalAssets,
                        attachments: attachments,
                        valuation: valuation,
                        sales: sales,
                        saleLines: recordedSaleLines,
                        alerts: alerts,
                        isRefreshing: marketStore.isRefreshing,
                        refresh: refreshMarket
                    )
                }
            } label: {
                Label("tabs.sale", systemImage: "equal.circle.fill")
                    .accessibilityIdentifier("tab.sale")
            }

            Tab(value: .settings) {
                NavigationStack {
                    SettingsView(
                        portfolioValuation: valuation,
                        valuationAsOf: valuationAsOf
                    )
                }
            } label: {
                Label("tabs.settings", systemImage: "gearshape.fill")
                    .accessibilityIdentifier("tab.settings")
            }
        }
        .environment(router)
        .environment(marketStore)
        .sheet(item: $router.sheet) { destination in
            sheet(for: destination)
        }
        .fullScreenCover(item: $router.cover) { destination in
            cover(for: destination)
        }
        .task {
            TemporaryVaultReportFileStore.purgeStaleReports()
            purgeExpiredAssets()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            purgeExpiredAssets()
            Task {
                await evaluatePriceAlerts()
            }
        }
        .task(id: requiredPairs) {
            await marketStore.load(pairs: requiredPairs)
            valuationAsOf = marketStore.lastRefreshAt ?? Date()
            await evaluatePriceAlerts()

            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(60))
                } catch {
                    return
                }
                await marketStore.refresh(pairs: requiredPairs)
                valuationAsOf = marketStore.lastRefreshAt ?? valuationAsOf
                await evaluatePriceAlerts()
            }
        }
        .task(id: priceAlertBackgroundWorkIDs) {
            if priceAlertBackgroundWorkIDs.isEmpty {
                PriceAlertBestEffortBackgroundRefresh.cancel()
            } else {
                await PriceAlertBestEffortBackgroundRefresh.schedule()
            }
        }
        .task(id: priceAlertNotificationNavigationInbox.pendingRequest) {
            guard let request =
                priceAlertNotificationNavigationInbox.pendingRequest
            else {
                return
            }

            router.showPriceAlertFromNotification(
                request,
                availableAlertIDs: Set(canonicalAlerts.map(\.id))
            )
            priceAlertNotificationNavigationInbox.consume(request)
        }
        .background(theme.background)
    }

    @ViewBuilder
    private func destination(
        for route: AppRoute,
        portfolioValuation: PortfolioValuation
    ) -> some View {
        switch route {
        case .inventory:
            InventoryView(
                assets: heldAssets,
                attachments: heldAttachments,
                valuation: portfolioValuation,
                isRefreshing: marketStore.isRefreshing,
                repository: SwiftDataAssetRepository(modelContext: modelContext)
            )
        case let .assetDetail(assetID):
            if let asset = asset(withID: assetID) {
                let heldQuantity = heldQuantity(for: asset)
                let detailValuation = valuationEngine.valuate(
                    assets: [asset.portfolioSnapshot(heldQuantity: heldQuantity)],
                    market: marketStore.marketSnapshot,
                    historyMonths: nil,
                    asOf: valuationAsOf
                )
                AssetDetailView(
                    asset: asset,
                    attachments: heldAttachments,
                    valuation: detailValuation.assetValuations.first,
                    history: detailValuation.history,
                    historyUsesUnknownPurchaseDates: detailValuation.historyUsesUnknownPurchaseDates,
                    valuationAsOf: valuationAsOf,
                    repository: SwiftDataAssetRepository(modelContext: modelContext)
                )
            } else {
                MissingAssetView()
            }
        case let .assetDocuments(assetID):
            if let asset = asset(withID: assetID) {
                AssetDocumentsView(
                    asset: asset,
                    repository: SwiftDataAssetRepository(modelContext: modelContext)
                )
            } else {
                MissingAssetView()
            }
        }
    }

    @ViewBuilder
    private func sheet(for destination: AppSheetDestination) -> some View {
        switch destination {
        case let .editAsset(assetID):
            if let asset = asset(withID: assetID) {
                AssetEditorView(
                    asset: asset,
                    repository: SwiftDataAssetRepository(modelContext: modelContext)
                )
            } else {
                NavigationStack {
                    MissingAssetView()
                }
            }
        }
    }

    @ViewBuilder
    private func cover(for destination: AppCoverDestination) -> some View {
        switch destination {
        case .assetCreation:
            AssetCreationFlowView(
                state: AssetCreationState(
                    analyzer: analyzer,
                    analysisPreferences: analysisPreferences,
                    saver: SwiftDataAssetRepository(modelContext: modelContext)
                )
            )
        }
    }

    private var originalSnapshots: [PortfolioAssetSnapshot] {
        canonicalAssets.map(\.portfolioSnapshot)
    }

    private var heldSnapshots: [PortfolioAssetSnapshot] {
        heldAssets.map { asset in
            asset.portfolioSnapshot(heldQuantity: heldQuantity(for: asset))
        }
    }

    private var portfolioValuation: PortfolioValuation {
        valuationCache.value(
            for: PortfolioValuationInput(
                heldAssets: heldSnapshots,
                originalAssets: originalSnapshots,
                saleEvents: saleHistoryEvents,
                market: marketStore.marketSnapshot,
                asOf: valuationAsOf
            ),
            using: valuationEngine
        )
    }

    private var canonicalAssets: [Asset] {
        AssetCanonicalization.canonicalAssets(from: assets)
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var canonicalSales: [Sale] {
        SalesRepository.canonicalSales(from: sales)
            .sorted { lhs, rhs in
                if lhs.soldAt == rhs.soldAt {
                    if lhs.createdAt == rhs.createdAt {
                        return lhs.id.uuidString < rhs.id.uuidString
                    }
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.soldAt > rhs.soldAt
            }
    }

    private var canonicalAlerts: [PriceAlert] {
        SalesRepository.canonicalAlerts(from: alerts)
            .sorted {
                if $0.createdAt == $1.createdAt {
                    return $0.id.uuidString < $1.id.uuidString
                }
                return $0.createdAt > $1.createdAt
            }
    }

    private var recordedSales: [Sale] {
        canonicalSales.filter { $0.status == .recorded }
    }

    private var priceAlertBackgroundWorkIDs: [String] {
        let activeAlertIDs = canonicalAlerts
            .filter { $0.status == .active }
            .map { "alert:\($0.id.uuidString)" }
        let pendingNotificationIDs = pendingPriceAlertNotifications.map {
            "notification:\($0.notificationIdentifier)"
        }
        return (activeAlertIDs + pendingNotificationIDs).sorted()
    }

    private var recordedSaleLines: [SaleLine] {
        SalesRepository.recordedSaleLines(
            from: saleLines,
            salesByID: SalesRepository.canonicalSalesByID(from: sales)
        )
        .sorted { $0.id.uuidString < $1.id.uuidString }
    }

    private var heldAssets: [Asset] {
        canonicalAssets.filter { heldQuantity(for: $0) > 0 }
    }

    private var heldAttachments: [AssetAttachment] {
        let heldAssetIDs = Set(heldAssets.map(\.id))
        return attachments.filter { heldAssetIDs.contains($0.assetID) }
    }

    private var storageLocationsByAssetID: [UUID: String] {
        var locations: [UUID: String] = [:]
        for asset in heldAssets {
            guard let name = asset.storageLocationName?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !name.isEmpty
            else {
                continue
            }
            locations[asset.id] = name
        }
        return locations
    }

    private var saleHistoryEvents: [PortfolioSaleHistoryEvent] {
        var recordedSalesByID: [UUID: Sale] = [:]
        for sale in recordedSales {
            recordedSalesByID[sale.id] = sale
        }
        return recordedSaleLines.compactMap { line in
            guard let sale = recordedSalesByID[line.saleID] else { return nil }
            return PortfolioSaleHistoryEvent(
                id: line.id,
                occurredAt: sale.soldAt,
                soldQuantity: line.quantity,
                assetSnapshotBeforeSale: line.portfolioSnapshotBeforeSale
            )
        }
    }

    private var analyticsSales: [PortfolioAnalyticsSaleEntry] {
        let linesBySaleID = Dictionary(grouping: recordedSaleLines, by: \.saleID)
        return recordedSales.map { sale in
            let lines = linesBySaleID[sale.id] ?? []
            let isEUR = sale.currencyCode == MarketCurrency.eur.rawValue
            return PortfolioAnalyticsSaleEntry(
                id: sale.id,
                soldAt: sale.soldAt,
                grossProceedsEUR: isEUR ? sale.grossAmount : nil,
                feesEUR: isEUR ? sale.feesAmount : nil,
                purchaseCostEUR: euroAllocatedPurchaseCost(for: lines),
                spotValueAtSaleEUR: isEUR
                    && lines.allSatisfy {
                        $0.saleCurrencyCode == MarketCurrency.eur.rawValue
                    }
                    ? completeSum(lines.map(\.spotValueAtSale))
                    : nil
            )
        }
    }

    private var metalQuotes: [MarketMetal: SpotQuote] {
        Dictionary(uniqueKeysWithValues: MarketMetal.allCases.compactMap { metal in
            marketStore.quote(for: metal).map { (metal, $0) }
        })
    }

    private var requiredPairs: Set<SpotPair> {
        homeRequiredSpotPairs(for: heldSnapshots)
    }

    private func asset(withID id: UUID) -> Asset? {
        heldAssets.first { $0.id == id }
    }

    private func heldQuantity(for asset: Asset) -> Int {
        SalesLedger.heldQuantity(
            for: asset,
            recordedSaleLines: recordedSaleLines
        )
    }

    private func euroAllocatedPurchaseCost(
        for lines: [SaleLine]
    ) -> Decimal? {
        guard !lines.isEmpty,
              lines.allSatisfy({
                  $0.purchaseCurrencyCodeSnapshot == MarketCurrency.eur.rawValue
              })
        else {
            return nil
        }
        return completeSum(lines.map(\.allocatedPurchaseCostAmountSnapshot))
    }

    private func completeSum(_ values: [Decimal?]) -> Decimal? {
        guard !values.isEmpty, values.allSatisfy({ $0 != nil }) else {
            return nil
        }
        return values.compactMap { $0 }.reduce(0, +)
    }

    private func refreshMarket() async {
        await marketStore.refresh(pairs: requiredPairs)
        valuationAsOf = marketStore.lastRefreshAt ?? valuationAsOf
        await evaluatePriceAlerts()
    }

    private func evaluatePriceAlerts() async {
        var valuations: [UUID: PriceAlertAssetValuation] = [:]
        for valuation in portfolioValuation.assetValuations {
            guard let amount = valuation.estimatedValueEUR else {
                continue
            }
            valuations[valuation.assetID] = PriceAlertAssetValuation(
                assetID: valuation.assetID,
                amount: amount,
                currencyCode: MarketCurrency.eur.rawValue
            )
        }

        do {
            try await priceAlertEvaluator.evaluateActiveAlerts(
                canonicalAlerts,
                valuationsByAssetID: valuations
            )
            try modelContext.save()
        } catch is CancellationError {
            return
        } catch {
            return
        }
    }

    private func purgeExpiredAssets() {
        let repository = SwiftDataAssetRepository(modelContext: modelContext)
        let cutoff = AssetTrashPolicy.expirationCutoff(asOf: .now)
        try? repository.purgeExpiredAssets(olderThan: cutoff)
    }
}

private nonisolated struct PortfolioValuationInput: Equatable, Sendable {
    let heldAssets: [PortfolioAssetSnapshot]
    let originalAssets: [PortfolioAssetSnapshot]
    let saleEvents: [PortfolioSaleHistoryEvent]
    let market: PortfolioMarketSnapshot
    let asOf: Date
}

private final class PortfolioValuationCache {
    private var input: PortfolioValuationInput?
    private var output: PortfolioValuation?

    func value(
        for input: PortfolioValuationInput,
        using engine: PortfolioValuationEngine
    ) -> PortfolioValuation {
        if self.input == input, let output {
            return output
        }

        let current = engine.valuate(
            assets: input.heldAssets,
            market: input.market,
            historyMonths: nil,
            asOf: input.asOf
        )
        let history = PortfolioHoldingHistoryEngine().history(
            assets: input.originalAssets,
            saleEvents: input.saleEvents,
            market: input.market,
            asOf: input.asOf
        )
        let output = PortfolioValuation(
            totalEstimatedValueEUR: current.totalEstimatedValueEUR,
            totalPurchaseCostEUR: current.totalPurchaseCostEUR,
            totalGainEUR: current.totalGainEUR,
            gainPercentage: current.gainPercentage,
            assetValuations: current.assetValuations,
            metals: current.metals,
            categories: current.categories,
            coverage: current.coverage,
            history: history,
            historyUsesUnknownPurchaseDates: !history.isEmpty
                && input.originalAssets.contains { $0.purchaseDate == nil }
        )
        self.input = input
        self.output = output
        return output
    }
}

nonisolated func homeRequiredSpotPairs(
    for assets: [PortfolioAssetSnapshot]
) -> Set<SpotPair> {
    PortfolioValuationEngine.requiredSpotPairs(for: assets)
        .union(MarketDataStore.defaultPairs)
}

private struct MissingAssetView: View {
    @Environment(KaraTheme.self) private var theme

    var body: some View {
        ContentUnavailableView {
            Label("asset-missing.title", systemImage: "shippingbox.and.arrow.backward")
        } description: {
            Text("asset-missing.body")
        }
        .foregroundStyle(theme.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background.ignoresSafeArea())
    }
}
