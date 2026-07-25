import Foundation
import Testing
@testable import KARA

@Suite("Market data disk cache")
struct MarketDataCacheTests {
    @Test("A bootstrap cache entry persists atomically as one resource")
    func persistsBootstrapAsOneResource() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "KARA-MarketDataCacheTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let bootstrap = makeBootstrap(dataVersion: "version-a")
        let entry = CachedMarketResource(
            value: bootstrap,
            etag: "bootstrap-tag",
            savedAt: Date(timeIntervalSince1970: 100)
        )
        let firstCache = DiskMarketDataCache(directory: directory)

        try await firstCache.saveBootstrap(entry)
        let reopenedCache = DiskMarketDataCache(directory: directory)

        #expect(try await reopenedCache.cachedBootstrap() == entry)
    }

    @Test("A monthly cache entry persists its HTTP ETag and business data version separately")
    func persistsMonthlyVersionMetadata() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "KARA-MarketDataCacheTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let dataset = MonthlyDataset(
            unit: MarketUnit(code: .troyOunce, grams: Decimal(string: "31.1034768")!),
            series: []
        )
        let entry = CachedMonthlyResource(
            value: dataset,
            etag: "\"version-a\"",
            dataVersion: "version-a",
            savedAt: Date(timeIntervalSince1970: 100)
        )
        let firstCache = DiskMarketDataCache(directory: directory)

        try await firstCache.saveMonthly(entry)
        let reopenedCache = DiskMarketDataCache(directory: directory)

        #expect(try await reopenedCache.cachedMonthly() == entry)
    }

    @Test("Spot cache entries survive a new cache instance and remain keyed by pair")
    func persistsSpotEntriesByPair() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "KARA-MarketDataCacheTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let goldEUR = SpotPair(metal: .gold, currency: .eur)
        let silverEUR = SpotPair(metal: .silver, currency: .eur)
        let quote = SpotQuote(
            metal: .gold,
            currency: .eur,
            price: Decimal(string: "3558.900966")!,
            unit: MarketUnit(code: .troyOunce, grams: Decimal(string: "31.1034768")!),
            sourceUpdatedAt: Date(timeIntervalSince1970: 1_784_627_133)
        )
        let entry = CachedMarketResource(value: quote, etag: "spot-tag", savedAt: Date(timeIntervalSince1970: 100))
        let firstCache = DiskMarketDataCache(directory: directory)

        try await firstCache.saveSpot(entry, for: goldEUR)
        let reopenedCache = DiskMarketDataCache(directory: directory)

        #expect(try await reopenedCache.cachedSpot(for: goldEUR) == entry)
        #expect(try await reopenedCache.cachedSpot(for: silverEUR) == nil)
    }
}

private func makeBootstrap(dataVersion: String) -> MarketBootstrap {
    let unit = MarketUnit(code: .troyOunce, grams: Decimal(string: "31.1034768")!)
    let spots = MarketMetal.allCases.enumerated().map { offset, metal in
        SpotQuote(
            metal: metal,
            currency: .eur,
            price: Decimal(3_000 + offset),
            unit: unit,
            sourceUpdatedAt: Date(timeIntervalSince1970: 100)
        )
    }
    let manifest = MarketManifest(
        schemaVersion: 1,
        datasetId: "precious-metals-monthly",
        dataVersion: dataVersion,
        publishedAt: Date(timeIntervalSince1970: 100),
        metals: MarketMetal.allCases,
        coverage: .init(from: "2020-01", through: "2026-07"),
        currencies: ["EUR": .init(from: "2020-01", through: "2026-07")],
        file: .init(url: "/v1/metals-monthly.json", sha256: dataVersion, bytes: 100)
    )
    return MarketBootstrap(manifest: manifest, spots: spots)
}
