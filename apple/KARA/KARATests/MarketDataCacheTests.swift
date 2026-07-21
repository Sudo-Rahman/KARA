import Foundation
import Testing
@testable import KARA

@Suite("Market data disk cache")
struct MarketDataCacheTests {
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
