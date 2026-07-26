import SwiftData
import SwiftUI

struct AppShellView: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AIFormAutofillPreferences.self) private var analysisPreferences

    @Query(
        filter: #Predicate<Asset> { $0.deletedAt == nil },
        sort: \Asset.createdAt,
        order: .reverse
    ) private var assets: [Asset]
    @Query(sort: \AssetAttachment.createdAt, order: .reverse) private var attachments: [AssetAttachment]

    private let analyzer: any AssetAnalyzing = RemoteAssetAnalysisService()
    private let valuationEngine = PortfolioValuationEngine()

    @State private var router = AppRouter()
    @State private var marketStore = MarketDataStore.live()
    @State private var valuationCache = PortfolioValuationCache()
    @State private var valuationAsOf = Date()
    @State private var selectedTab: AppTab = .vault

    var body: some View {
        @Bindable var router = router
        let valuation = valuationCache.value(
            for: PortfolioValuationInput(
                assets: snapshots,
                market: marketStore.marketSnapshot,
                asOf: valuationAsOf
            ),
            using: valuationEngine
        )
        let attachments = activeAttachments

        TabView(selection: $selectedTab) {
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

            Tab(value: .sale) {
                NavigationStack {
                    SaleSimulationView(
                        assets: assets,
                        attachments: attachments,
                        valuation: valuation
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
        }
        .task(id: requiredPairs) {
            await marketStore.load(pairs: requiredPairs)
            valuationAsOf = marketStore.lastRefreshAt ?? Date()

            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(60))
                } catch {
                    return
                }
                await marketStore.refresh(pairs: requiredPairs)
                valuationAsOf = marketStore.lastRefreshAt ?? valuationAsOf
            }
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
                assets: assets,
                attachments: activeAttachments,
                valuation: portfolioValuation,
                isRefreshing: marketStore.isRefreshing,
                repository: SwiftDataAssetRepository(modelContext: modelContext)
            )
        case let .assetDetail(assetID):
            if let asset = asset(withID: assetID) {
                let detailValuation = valuationEngine.valuate(
                    assets: [asset.portfolioSnapshot],
                    market: marketStore.marketSnapshot,
                    historyMonths: nil,
                    asOf: valuationAsOf
                )
                AssetDetailView(
                    asset: asset,
                    attachments: activeAttachments,
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

    private var snapshots: [PortfolioAssetSnapshot] {
        assets.map(\.portfolioSnapshot)
    }

    private var activeAttachments: [AssetAttachment] {
        let activeAssetIDs = Set(assets.map(\.id))
        return attachments.filter { activeAssetIDs.contains($0.assetID) }
    }

    private var metalQuotes: [MarketMetal: SpotQuote] {
        Dictionary(uniqueKeysWithValues: MarketMetal.allCases.compactMap { metal in
            marketStore.quote(for: metal).map { (metal, $0) }
        })
    }

    private var requiredPairs: Set<SpotPair> {
        homeRequiredSpotPairs(for: snapshots)
    }

    private func asset(withID id: UUID) -> Asset? {
        assets.first { $0.id == id }
    }

    private func refreshMarket() async {
        await marketStore.refresh(pairs: requiredPairs)
        valuationAsOf = marketStore.lastRefreshAt ?? valuationAsOf
    }

    private func purgeExpiredAssets() {
        let repository = SwiftDataAssetRepository(modelContext: modelContext)
        let cutoff = AssetTrashPolicy.expirationCutoff(asOf: .now)
        try? repository.purgeExpiredAssets(olderThan: cutoff)
    }
}

private nonisolated struct PortfolioValuationInput: Equatable, Sendable {
    let assets: [PortfolioAssetSnapshot]
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

        let output = engine.valuate(
            assets: input.assets,
            market: input.market,
            historyMonths: nil,
            asOf: input.asOf
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
