import Foundation
import Testing
@testable import KARA

@Suite("Market data store", .serialized)
struct MarketDataStoreTests {
    @Test("The home always requests all four EUR metal quotes")
    func homeRequestsEveryMetalQuote() {
        #expect(
            homeRequiredSpotPairs(for: [])
                == Set(MarketMetal.allCases.map { SpotPair(metal: $0, currency: .eur) })
        )
    }

    @Test("Load publishes disk cache before a pending refresh and then publishes live data")
    @MainActor
    func loadsCacheBeforeRefresh() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "KARA-MarketDataStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let pair = SpotPair(metal: .gold, currency: .eur)
        let cachedQuote = makeQuote(price: 3_000, updatedAt: Date(timeIntervalSince1970: 100))
        let liveQuote = makeQuote(price: 3_100, updatedAt: Date(timeIntervalSince1970: 200))
        let cache = DiskMarketDataCache(directory: directory)
        try await cache.saveSpot(
            CachedMarketResource(value: cachedQuote, etag: "cached-tag", savedAt: Date(timeIntervalSince1970: 150)),
            for: pair
        )
        let client = SuspendedSpotClient()
        let store = MarketDataStore(client: client, cache: cache, now: { Date(timeIntervalSince1970: 250) })

        let load = Task { await store.load(pairs: [pair]) }
        await client.waitUntilSpotIsRequested()

        #expect(store.quote(for: .gold, currency: .eur) == cachedQuote)
        #expect(store.isRefreshing)

        await client.completeSpot(with: .modified(liveQuote, etag: "live-tag"))
        await load.value

        #expect(store.quote(for: .gold, currency: .eur) == liveQuote)
        #expect(!store.isRefreshing)
        #expect(store.lastError == nil)
    }

    @Test("A failed refresh preserves cached values and marks them as delayed")
    @MainActor
    func preservesCacheOnRefreshFailure() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "KARA-MarketDataStoreTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let pair = SpotPair(metal: .gold, currency: .eur)
        let cachedQuote = makeQuote(price: 3_000, updatedAt: Date(timeIntervalSince1970: 100))
        let cache = DiskMarketDataCache(directory: directory)
        try await cache.saveSpot(
            CachedMarketResource(value: cachedQuote, etag: "cached-tag", savedAt: Date(timeIntervalSince1970: 150)),
            for: pair
        )
        let client = SuspendedSpotClient()
        let store = MarketDataStore(client: client, cache: cache, now: { Date(timeIntervalSince1970: 250) })

        let load = Task { await store.load(pairs: [pair]) }
        await client.waitUntilSpotIsRequested()
        await client.failSpot(with: URLError(.notConnectedToInternet))
        await load.value

        #expect(store.quote(for: .gold, currency: .eur) == cachedQuote)
        #expect(store.lastError?.phase == .refresh)
        #expect(store.isUsingCachedData)
    }

    private func makeQuote(price: Decimal, updatedAt: Date) -> SpotQuote {
        SpotQuote(
            metal: .gold,
            currency: .eur,
            price: price,
            unit: MarketUnit(code: .troyOunce, grams: Decimal(string: "31.1034768")!),
            sourceUpdatedAt: updatedAt
        )
    }
}

private actor SuspendedSpotClient: MarketDataClient {
    private var continuation: CheckedContinuation<MarketFetchResult<SpotQuote>, Error>?

    func spot(for pair: SpotPair, etag: String?) async throws -> MarketFetchResult<SpotQuote> {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func monthly(etag: String?) async throws -> MarketFetchResult<MonthlyDataset> {
        .notModified(etag: etag)
    }

    func manifest(etag: String?) async throws -> MarketFetchResult<MarketManifest> {
        .notModified(etag: etag)
    }

    func waitUntilSpotIsRequested() async {
        while continuation == nil {
            await Task.yield()
        }
    }

    func completeSpot(with result: MarketFetchResult<SpotQuote>) {
        continuation?.resume(returning: result)
        continuation = nil
    }

    func failSpot(with error: URLError) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
