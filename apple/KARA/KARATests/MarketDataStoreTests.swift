import Foundation
import Testing
@testable import KARA

@Suite("Market data store", .serialized)
struct MarketDataStoreTests {
#if DEBUG
    @Test("The visual QA market fixture requires all three exact launch flags")
    func visualQAFixtureRequiresExactLaunchFlags() {
        let required = [
            KaraModelContainerFactory.inMemoryLaunchArgument,
            VisualQAVaultSeeder.launchArgument,
            MarketDataStore.cachedOnlyLaunchArgument,
        ]

        #expect(VisualQAMarketDataFixture.isEnabled(arguments: required))
        #expect(VisualQAMarketDataFixture.isEnabled(arguments: required + ["-AppleLanguages", "(en)"]))
        for missingIndex in required.indices {
            var incomplete = required
            incomplete.remove(at: missingIndex)
            #expect(!VisualQAMarketDataFixture.isEnabled(arguments: incomplete))
        }
        #expect(!VisualQAMarketDataFixture.isEnabled(arguments: required.map { $0 + "-near-miss" }))
    }

    @Test("The visual QA launch publishes four EUR quotes and twelve months per metal")
    @MainActor
    func visualQAFixturePublishesCompleteCoverage() async throws {
        let store = MarketDataStore.live(arguments: [
            KaraModelContainerFactory.inMemoryLaunchArgument,
            VisualQAVaultSeeder.launchArgument,
            MarketDataStore.cachedOnlyLaunchArgument,
        ])

        await store.load()

        let quotes = try MarketMetal.allCases.map { metal in
            try #require(store.quote(for: metal, currency: .eur))
        }
        #expect(quotes.map(\.metal) == MarketMetal.allCases)
        #expect(quotes.allSatisfy { $0.price > 0 && $0.sourceUpdatedAt == VisualQAMarketDataFixture.timestamp })

        let monthly = try #require(store.monthlyDataset)
        #expect(monthly.series.map(\.metal) == MarketMetal.allCases)
        #expect(monthly.series.allSatisfy { series in
            series.observations.count == 12
                && series.observations.first?.month == "2025-09"
                && series.observations.last?.month == "2026-08"
                && series.observations.allSatisfy { $0.price(in: .eur).map { $0 > 0 } == true }
        })
        #expect(store.manifest?.dataVersion == VisualQAMarketDataFixture.dataVersion)
        #expect(try VisualQAMarketDataFixture.bootstrap.validated() == VisualQAMarketDataFixture.bootstrap)
        #expect(try VisualQAMarketDataFixture.monthlyDataset.validated() == monthly)
    }
#endif

    @Test("The home always requests all four EUR metal quotes")
    func homeRequestsEveryMetalQuote() {
        #expect(
            homeRequiredSpotPairs(for: [])
                == Set(MarketMetal.allCases.map { SpotPair(metal: $0, currency: .eur) })
        )
    }

    @Test("Refresh uses one bootstrap and skips monthly when the cached data version matches")
    @MainActor
    func refreshesWithOneBootstrapAndNoUnneededMonthly() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "KARA-MarketDataStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let bootstrap = makeStoreBootstrap(dataVersion: "version-a")
        let monthly = makeMonthlyDataset()
        let cache = DiskMarketDataCache(directory: directory)
        try await cache.saveBootstrap(CachedMarketResource(
            value: bootstrap,
            etag: "bootstrap-tag",
            savedAt: Date(timeIntervalSince1970: 100)
        ))
        try await cache.saveMonthly(CachedMonthlyResource(
            value: monthly,
            etag: "\"version-a\"",
            dataVersion: "version-a",
            savedAt: Date(timeIntervalSince1970: 100)
        ))
        let client = RecordingMarketClient(bootstrap: .notModified(etag: "bootstrap-tag"))
        let store = MarketDataStore(client: client, cache: cache)

        await store.load()

        #expect(await client.bootstrapRequestCount == 1)
        #expect(await client.monthlyRequestCount == 0)
        #expect(store.manifest == bootstrap.manifest)
        #expect(store.monthlyDataset == monthly)
    }

    @Test("Refresh fetches only requested non-EUR pairs outside the bootstrap")
    @MainActor
    func refreshesRequestedNonEURPairs() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "KARA-MarketDataStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let bootstrap = makeStoreBootstrap(dataVersion: "version-a")
        let monthly = makeMonthlyDataset()
        let cache = DiskMarketDataCache(directory: directory)
        try await cache.saveBootstrap(CachedMarketResource(
            value: bootstrap,
            etag: "bootstrap-tag",
            savedAt: Date(timeIntervalSince1970: 100)
        ))
        try await cache.saveMonthly(CachedMonthlyResource(
            value: monthly,
            etag: "\"version-a\"",
            dataVersion: "version-a",
            savedAt: Date(timeIntervalSince1970: 100)
        ))
        let usdPair = SpotPair(metal: .gold, currency: .usd)
        let usdQuote = SpotQuote(
            metal: .gold,
            currency: .usd,
            price: 3_500,
            unit: MarketUnit(code: .troyOunce, grams: Decimal(string: "31.1034768")!),
            sourceUpdatedAt: Date(timeIntervalSince1970: 200)
        )
        let client = ExtraPairMarketClient(
            bootstrap: .notModified(etag: "bootstrap-tag"),
            quote: usdQuote
        )
        let store = MarketDataStore(client: client, cache: cache)

        await store.load(pairs: Set(MarketBootstrap.expectedPairs + [usdPair]))

        #expect(await client.requestedPairs == [usdPair])
        #expect(store.quote(for: .gold, currency: .usd) == usdQuote)
        #expect(await client.monthlyRequestCount == 0)
    }

    @Test("A refresh requested while another is running is replayed with the latest pairs")
    @MainActor
    func replaysLatestPairsAfterConcurrentRefresh() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "KARA-MarketDataStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let client = SuspendedBootstrapClient()
        let store = MarketDataStore(
            client: client,
            cache: DiskMarketDataCache(directory: directory)
        )
        let usdPair = SpotPair(metal: .gold, currency: .usd)

        let firstRefresh = Task { await store.refresh() }
        #expect(await client.waitUntilBootstrapRequestCount(1))

        let latestRefresh = Task {
            await store.refresh(pairs: Self.defaultPairsForTest.union([usdPair]))
        }
        await Task.yield()
        await client.completeBootstrap(with: .modified(
            makeStoreBootstrap(dataVersion: "version-a"),
            etag: "bootstrap-tag"
        ))

        let replayed = await client.waitUntilBootstrapRequestCount(2)
        #expect(replayed)
        if replayed {
            await client.completeBootstrap(with: .notModified(etag: "bootstrap-tag"))
        }

        await firstRefresh.value
        await latestRefresh.value
        #expect(await client.requestedPairs == [usdPair])
    }

    @Test("An obsolete monthly cache triggers exactly one monthly request")
    @MainActor
    func refreshesObsoleteMonthlyOnce() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "KARA-MarketDataStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let bootstrap = makeStoreBootstrap(dataVersion: "version-a")
        let cache = DiskMarketDataCache(directory: directory)
        try await cache.saveBootstrap(CachedMarketResource(
            value: bootstrap,
            etag: "bootstrap-tag",
            savedAt: Date(timeIntervalSince1970: 100)
        ))
        try await cache.saveMonthly(CachedMonthlyResource(
            value: makeMonthlyDataset(),
            etag: "\"version-old\"",
            dataVersion: "version-old",
            savedAt: Date(timeIntervalSince1970: 100)
        ))
        let client = RecordingMarketClient(
            bootstrap: .notModified(etag: "bootstrap-tag"),
            monthly: .modified(makeMonthlyDataset(), etag: "\"version-a\"")
        )
        let store = MarketDataStore(client: client, cache: cache)

        await store.load()

        #expect(await client.bootstrapRequestCount == 1)
        #expect(await client.monthlyRequestCount == 1)
        #expect(try await cache.cachedMonthly()?.dataVersion == "version-a")
    }

    @Test("A publication race rereads bootstrap and retries monthly at most once")
    @MainActor
    func recoversOnePublicationRace() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "KARA-MarketDataStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let versionA = makeStoreBootstrap(dataVersion: "version-a")
        let versionB = makeStoreBootstrap(dataVersion: "version-b", price: 3_100)
        let cache = DiskMarketDataCache(directory: directory)
        try await cache.saveBootstrap(CachedMarketResource(
            value: versionA,
            etag: "bootstrap-a",
            savedAt: Date(timeIntervalSince1970: 100)
        ))
        let client = PublicationRaceMarketClient(
            bootstrapResults: [
                .notModified(etag: "bootstrap-a"),
                .modified(versionB, etag: "bootstrap-b"),
            ],
            monthlyResults: [
                .modified(makeMonthlyDataset(), etag: "\"version-b\""),
                .modified(makeMonthlyDataset(), etag: "\"version-b\""),
            ]
        )
        let store = MarketDataStore(client: client, cache: cache)

        await store.load()

        #expect(await client.bootstrapRequestCount == 2)
        #expect(await client.monthlyRequestCount == 2)
        #expect(store.manifest?.dataVersion == "version-b")
        #expect(try await cache.cachedMonthly()?.dataVersion == "version-b")
        #expect(store.lastError == nil)
    }

    @Test("Load publishes disk cache before a pending refresh and then publishes live data")
    @MainActor
    func loadsCacheBeforeRefresh() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "KARA-MarketDataStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cachedBootstrap = makeStoreBootstrap(dataVersion: "version-a", price: 3_000)
        let liveBootstrap = makeStoreBootstrap(dataVersion: "version-a", price: 3_100)
        let cache = DiskMarketDataCache(directory: directory)
        try await cache.saveBootstrap(CachedMarketResource(
            value: cachedBootstrap,
            etag: "cached-tag",
            savedAt: Date(timeIntervalSince1970: 150)
        ))
        try await cache.saveMonthly(CachedMonthlyResource(
            value: makeMonthlyDataset(),
            etag: "\"version-a\"",
            dataVersion: "version-a",
            savedAt: Date(timeIntervalSince1970: 150)
        ))
        let client = SuspendedBootstrapClient()
        let store = MarketDataStore(client: client, cache: cache, now: { Date(timeIntervalSince1970: 250) })

        let load = Task { await store.load() }
        await client.waitUntilBootstrapIsRequested()

        #expect(store.quote(for: .gold, currency: .eur)?.price == 3_000)
        #expect(store.isRefreshing)

        await client.completeBootstrap(with: .modified(liveBootstrap, etag: "live-tag"))
        await load.value

        #expect(store.quote(for: .gold, currency: .eur)?.price == 3_100)
        #expect(!store.isRefreshing)
        #expect(store.lastError == nil)
    }

    @Test("A failed refresh preserves cached values and marks them as delayed")
    @MainActor
    func preservesCacheOnRefreshFailure() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "KARA-MarketDataStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cachedBootstrap = makeStoreBootstrap(dataVersion: "version-a", price: 3_000)
        let cache = DiskMarketDataCache(directory: directory)
        try await cache.saveBootstrap(CachedMarketResource(
            value: cachedBootstrap,
            etag: "cached-tag",
            savedAt: Date(timeIntervalSince1970: 150)
        ))
        let client = SuspendedBootstrapClient()
        let store = MarketDataStore(client: client, cache: cache, now: { Date(timeIntervalSince1970: 250) })

        let load = Task { await store.load() }
        await client.waitUntilBootstrapIsRequested()
        await client.failBootstrap(with: URLError(.notConnectedToInternet))
        await load.value

        #expect(store.quote(for: .gold, currency: .eur)?.price == 3_000)
        #expect(store.lastError?.phase == .refresh)
        #expect(store.isUsingCachedData)
    }
}

private extension MarketDataStoreTests {
    static var defaultPairsForTest: Set<SpotPair> {
        Set(MarketBootstrap.expectedPairs)
    }
}

nonisolated private func makeStoreBootstrap(
    dataVersion: String,
    price: Decimal = 3_000
) -> MarketBootstrap {
    let unit = MarketUnit(code: .troyOunce, grams: Decimal(string: "31.1034768")!)
    let spots = MarketMetal.allCases.enumerated().map { offset, metal in
        SpotQuote(
            metal: metal,
            currency: .eur,
            price: price + Decimal(offset),
            unit: unit,
            sourceUpdatedAt: Date(timeIntervalSince1970: 100)
        )
    }
    return MarketBootstrap(
        manifest: MarketManifest(
            schemaVersion: 1,
            datasetId: "precious-metals-monthly",
            dataVersion: dataVersion,
            publishedAt: Date(timeIntervalSince1970: 100),
            metals: MarketMetal.allCases,
            coverage: .init(from: "2020-01", through: "2026-07"),
            currencies: ["EUR": .init(from: "2020-01", through: "2026-07")],
            file: .init(url: "/v1/metals-monthly.json", sha256: dataVersion, bytes: 100)
        ),
        spots: spots
    )
}

nonisolated private func makeMonthlyDataset() -> MonthlyDataset {
    MonthlyDataset(
        unit: MarketUnit(code: .troyOunce, grams: Decimal(string: "31.1034768")!),
        series: []
    )
}

private actor RecordingMarketClient: MarketDataClient {
    private(set) var bootstrapRequestCount = 0
    private(set) var monthlyRequestCount = 0
    let bootstrapResult: MarketFetchResult<MarketBootstrap>
    let monthlyResult: MarketFetchResult<MonthlyDataset>

    init(
        bootstrap: MarketFetchResult<MarketBootstrap>,
        monthly: MarketFetchResult<MonthlyDataset> = .notModified(etag: nil)
    ) {
        self.bootstrapResult = bootstrap
        self.monthlyResult = monthly
    }

    func bootstrap(etag: String?) async throws -> MarketFetchResult<MarketBootstrap> {
        bootstrapRequestCount += 1
        return bootstrapResult
    }

    func monthly(etag: String?) async throws -> MarketFetchResult<MonthlyDataset> {
        monthlyRequestCount += 1
        return monthlyResult
    }

    func spot(for pair: SpotPair, etag: String?) async throws -> MarketFetchResult<SpotQuote> {
        .notModified(etag: etag)
    }

    func manifest(etag: String?) async throws -> MarketFetchResult<MarketManifest> {
        .notModified(etag: etag)
    }
}

private actor SuspendedBootstrapClient: MarketDataClient {
    private var continuation: CheckedContinuation<MarketFetchResult<MarketBootstrap>, Error>?
    private(set) var bootstrapRequestCount = 0
    private(set) var requestedPairs: [SpotPair] = []

    func bootstrap(etag: String?) async throws -> MarketFetchResult<MarketBootstrap> {
        bootstrapRequestCount += 1
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func spot(for pair: SpotPair, etag: String?) async throws -> MarketFetchResult<SpotQuote> {
        requestedPairs.append(pair)
        return .notModified(etag: etag)
    }

    func monthly(etag: String?) async throws -> MarketFetchResult<MonthlyDataset> {
        .modified(makeMonthlyDataset(), etag: "\"version-a\"")
    }

    func manifest(etag: String?) async throws -> MarketFetchResult<MarketManifest> {
        .notModified(etag: etag)
    }

    func waitUntilBootstrapIsRequested() async {
        while continuation == nil {
            await Task.yield()
        }
    }

    func waitUntilBootstrapRequestCount(_ expectedCount: Int) async -> Bool {
        for _ in 0..<10_000 {
            if bootstrapRequestCount >= expectedCount, continuation != nil {
                return true
            }
            await Task.yield()
        }
        return false
    }

    func completeBootstrap(with result: MarketFetchResult<MarketBootstrap>) {
        continuation?.resume(returning: result)
        continuation = nil
    }

    func failBootstrap(with error: URLError) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

private actor PublicationRaceMarketClient: MarketDataClient {
    private var bootstrapResults: [MarketFetchResult<MarketBootstrap>]
    private var monthlyResults: [MarketFetchResult<MonthlyDataset>]
    private(set) var bootstrapRequestCount = 0
    private(set) var monthlyRequestCount = 0

    init(
        bootstrapResults: [MarketFetchResult<MarketBootstrap>],
        monthlyResults: [MarketFetchResult<MonthlyDataset>]
    ) {
        self.bootstrapResults = bootstrapResults
        self.monthlyResults = monthlyResults
    }

    func bootstrap(etag: String?) async throws -> MarketFetchResult<MarketBootstrap> {
        bootstrapRequestCount += 1
        return bootstrapResults.removeFirst()
    }

    func monthly(etag: String?) async throws -> MarketFetchResult<MonthlyDataset> {
        monthlyRequestCount += 1
        return monthlyResults.removeFirst()
    }

    func spot(for pair: SpotPair, etag: String?) async throws -> MarketFetchResult<SpotQuote> {
        .notModified(etag: etag)
    }

    func manifest(etag: String?) async throws -> MarketFetchResult<MarketManifest> {
        .notModified(etag: etag)
    }
}

private actor ExtraPairMarketClient: MarketDataClient {
    private let bootstrapResult: MarketFetchResult<MarketBootstrap>
    private let quote: SpotQuote
    private(set) var requestedPairs: [SpotPair] = []
    private(set) var monthlyRequestCount = 0

    init(bootstrap: MarketFetchResult<MarketBootstrap>, quote: SpotQuote) {
        self.bootstrapResult = bootstrap
        self.quote = quote
    }

    func bootstrap(etag: String?) async throws -> MarketFetchResult<MarketBootstrap> {
        bootstrapResult
    }

    func spot(for pair: SpotPair, etag: String?) async throws -> MarketFetchResult<SpotQuote> {
        requestedPairs.append(pair)
        return .modified(quote, etag: "usd-tag")
    }

    func monthly(etag: String?) async throws -> MarketFetchResult<MonthlyDataset> {
        monthlyRequestCount += 1
        return .notModified(etag: etag)
    }

    func manifest(etag: String?) async throws -> MarketFetchResult<MarketManifest> {
        .notModified(etag: etag)
    }
}
