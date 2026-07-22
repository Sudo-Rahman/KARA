import SwiftData
import SwiftUI

struct AppShellView: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Asset.createdAt, order: .reverse) private var assets: [Asset]
    @Query(sort: \AssetAttachment.createdAt, order: .reverse) private var attachments: [AssetAttachment]

    private let analyzer: any AssetAnalyzing
    private let valuationEngine = PortfolioValuationEngine()

    @State private var router: AppRouter
    @State private var marketStore: MarketDataStore
    @State private var valuationAsOf = Date()

    init(
        analyzer: any AssetAnalyzing = AppleAssetAnalysisService(),
        marketStore: MarketDataStore? = nil
    ) {
        self.analyzer = analyzer
        _router = State(initialValue: AppRouter())
        _marketStore = State(initialValue: marketStore ?? MarketDataStore.live())
    }

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            VaultDashboardView(
                assets: assets,
                attachments: attachments,
                valuation: portfolioValuation,
                metalQuotes: metalQuotes,
                isRefreshing: marketStore.isRefreshing,
                isUsingCachedMarketData: marketStore.isUsingCachedData,
                refresh: refreshMarket
            )
            .navigationDestination(for: AppRoute.self) { route in
                destination(for: route)
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
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .inventory:
            InventoryView(
                assets: assets,
                attachments: attachments,
                valuation: portfolioValuation,
                isRefreshing: marketStore.isRefreshing
            )
        case let .assetDetail(assetID):
            if let asset = asset(withID: assetID) {
                AssetDetailView(
                    asset: asset,
                    attachments: attachments,
                    valuation: assetValuation(withID: assetID)
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
        case .saleSimulation:
            SaleSimulationView(
                assets: assets,
                attachments: attachments,
                valuation: portfolioValuation
            )
        }
    }

    @ViewBuilder
    private func cover(for destination: AppCoverDestination) -> some View {
        switch destination {
        case .assetCreation:
            AssetCreationFlowView(
                state: AssetCreationState(
                    analyzer: analyzer,
                    saver: SwiftDataAssetRepository(modelContext: modelContext)
                )
            )
        }
    }

    private var snapshots: [PortfolioAssetSnapshot] {
        assets.map(\.portfolioSnapshot)
    }

    private var portfolioValuation: PortfolioValuation {
        valuationEngine.valuate(
            assets: snapshots,
            market: marketStore.marketSnapshot,
            historyMonths: nil,
            asOf: valuationAsOf
        )
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

    private func assetValuation(withID id: UUID) -> AssetValuation? {
        portfolioValuation.assetValuations.first { $0.assetID == id }
    }

    private func refreshMarket() async {
        await marketStore.refresh(pairs: requiredPairs)
        valuationAsOf = marketStore.lastRefreshAt ?? valuationAsOf
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

#Preview("Vault with one asset") {
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: Asset.self,
        AssetAttachment.self,
        SavedSeller.self,
        StorageLocation.self,
        configurations: configuration
    )
    let asset = Asset(
        name: "Lingotin 20 g",
        category: .bar,
        quantity: 1,
        purchaseDate: Date.now.addingTimeInterval(-86_400 * 180),
        metal: .gold,
        weightGrams: 20,
        finenessPermille: 999.9,
        pricePaidMinorUnits: 120_000,
        currencyCode: "EUR",
        storageLocationName: "Coffre principal",
        acquisitionMethod: .purchase,
        tags: ["Long terme"]
    )
    container.mainContext.insert(asset)

    return AppShellView(
        analyzer: PreviewAssetAnalyzer(),
        marketStore: MarketDataStore(
            client: PreviewMarketDataClient(),
            cache: PreviewMarketDataCache()
        )
    )
    .environment(KaraTheme())
    .environment(PrivacyPreferences(defaults: UserDefaults(suiteName: "kara.preview.vault")!))
    .modelContainer(container)
    .preferredColorScheme(.dark)
}

private struct PreviewAssetAnalyzer: AssetAnalyzing {
    func analyzeObjectPhoto(_ data: Data) async throws -> AssetAnalysisSuggestion {
        AssetAnalysisSuggestion()
    }

    func analyzeInvoice(
        _ data: Data,
        filename: String,
        mimeType: String
    ) async throws -> AssetAnalysisSuggestion {
        AssetAnalysisSuggestion()
    }
}

private struct PreviewMarketDataClient: MarketDataClient {
    func spot(for pair: SpotPair, etag: String?) async throws -> MarketFetchResult<SpotQuote> {
        let ouncePrice: Decimal = switch pair.metal {
        case .gold: 2_247.80
        case .silver: 29.40
        case .platinum: 1_020
        case .palladium: 980
        }
        return .modified(
            SpotQuote(
                metal: pair.metal,
                currency: pair.currency,
                price: ouncePrice,
                unit: MarketUnit(code: .troyOunce, grams: 31.103_476_8),
                sourceUpdatedAt: .now
            ),
            etag: nil
        )
    }

    func monthly(etag: String?) async throws -> MarketFetchResult<MonthlyDataset> {
        .notModified(etag: nil)
    }

    func manifest(etag: String?) async throws -> MarketFetchResult<MarketManifest> {
        .notModified(etag: nil)
    }
}

private actor PreviewMarketDataCache: MarketDataCaching {
    func cachedSpot(for pair: SpotPair) -> CachedMarketResource<SpotQuote>? { nil }
    func saveSpot(_ entry: CachedMarketResource<SpotQuote>, for pair: SpotPair) {}
    func cachedMonthly() -> CachedMarketResource<MonthlyDataset>? { nil }
    func saveMonthly(_ entry: CachedMarketResource<MonthlyDataset>) {}
    func cachedManifest() -> CachedMarketResource<MarketManifest>? { nil }
    func saveManifest(_ entry: CachedMarketResource<MarketManifest>) {}
}
