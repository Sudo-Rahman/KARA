import Foundation
import Testing
@testable import KARA

@Suite("Widget refresh without the host app")
struct KaraWidgetAutonomousRefreshTests {
    @Test("Two-day-old data is replaced by the extension without republishing from the app")
    func refreshesWithoutHost() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = KaraWidgetSnapshotStore(baseURL: directory)
        let oldDate = Date(timeIntervalSince1970: 1_785_000_000)
        let newDate = oldDate.addingTimeInterval(2 * 24 * 3600)
        try store.write(KaraWidgetSnapshot(generatedAt: oldDate, quotes: [
            KaraWidgetQuote(metal: .gold, ouncePrice: 100, unitGrams: 10, sourceUpdatedAt: oldDate)
        ], portfolio: nil, disclosure: .hidden))
        let loader = KaraWidgetTimelineLoader(store: store) { _ in
            [KaraWidgetMarketQuote(metal: .gold, currency: "EUR", price: 200,
                unitGrams: 10, sourceUpdatedAt: newDate)]
        }
        let result = await loader.load(now: newDate)
        #expect(result?.quote(for: .gold)?.ouncePrice == 200)
        #expect(result?.disclosure == .hidden)
        #expect(result?.portfolio == nil)
        #expect(try store.read()?.quote(for: .gold)?.ouncePrice == 100)
        let offline = KaraWidgetTimelineLoader(store: store) { _ in throw URLError(.notConnectedToInternet) }
        let retained = await offline.load(now: newDate.addingTimeInterval(3600))
        #expect(retained?.quote(for: .gold)?.ouncePrice == 200)
    }
    @Test("Mixed purchase currencies and unknown purchase costs match portfolio valuation")
    func revaluesPortfolio() throws {
        let old = Date(timeIntervalSince1970: 1_785_000_000)
        let fresh = old.addingTimeInterval(172800)
        let snapshot = KaraWidgetSnapshot(generatedAt: old, quotes: [],
            portfolio: KaraWidgetPortfolio(totalValueEUR: 30, totalGainEUR: 0, gainPercentage: 0,
                valuedRecordCount: 3, totalRecordCount: 4, objectCount: 5,
                history: [KaraWidgetHistoryPoint(date: old, valueEUR: 30)]),
            disclosure: .visible, holdings: [
                KaraWidgetHolding(metal: .gold, fineWeightGrams: 10, purchaseCost: 100, purchaseCurrency: "EUR"),
                KaraWidgetHolding(metal: .gold, fineWeightGrams: 10, purchaseCost: 100, purchaseCurrency: "USD"),
                KaraWidgetHolding(metal: .gold, fineWeightGrams: 10, purchaseCost: nil, purchaseCurrency: nil)
            ])
        let quotes = [
            KaraWidgetMarketQuote(metal: .gold, currency: "EUR", price: 200, unitGrams: 10, sourceUpdatedAt: fresh),
            KaraWidgetMarketQuote(metal: .gold, currency: "USD", price: 250, unitGrams: 10, sourceUpdatedAt: fresh)
        ]
        let result = snapshot.refreshing(with: quotes)
        #expect(result.portfolio?.totalValueEUR == 600)
        #expect(result.portfolio?.totalGainEUR == 220)
        #expect(result.portfolio?.gainPercentage == Decimal(220) / 180 * 100)
        #expect(result.generatedAt == fresh)
        #expect(result.portfolio?.totalRecordCount == 4)
        #expect(result.portfolio?.history == [KaraWidgetHistoryPoint(date: fresh, valueEUR: 600)])
        let incomplete = snapshot.refreshing(with: Array(quotes.prefix(1)))
        #expect(incomplete.portfolio == snapshot.portfolio)
        #expect(incomplete.generatedAt == old)
        #expect(incomplete.quote(for: .gold)?.ouncePrice == 200)
    }

    @Test("Masking during the network request cannot restore a visible portfolio")
    func maskingDuringRefresh() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = KaraWidgetSnapshotStore(baseURL: directory)
        try store.write(KaraWidgetSnapshot(generatedAt: .now, quotes: [],
            portfolio: KaraWidgetPortfolio(totalValueEUR: 100, totalGainEUR: nil, gainPercentage: nil,
                valuedRecordCount: 1, totalRecordCount: 1, objectCount: 1, history: []), disclosure: .visible))
        let loader = KaraWidgetTimelineLoader(store: store) { _ in
            try store.write(KaraWidgetSnapshot(generatedAt: .now, quotes: [], portfolio: nil, disclosure: .hidden))
            return [KaraWidgetMarketQuote(metal: .gold, currency: "EUR", price: 200,
                unitGrams: 10, sourceUpdatedAt: .now)]
        }
        let result = await loader.load()
        #expect(result?.disclosure == .hidden)
        #expect(result?.portfolio == nil)
        #expect(result?.holdings == nil)
    }

    @Test("Legacy snapshots decode without holdings and keep their truthful valuation date")
    func readsLegacySnapshot() throws {
        let data = Data(#"{"schemaVersion":1,"generatedAt":0,"quotes":[],"portfolio":null,"disclosure":"unavailable"}"#.utf8)
        let snapshot = try JSONDecoder().decode(KaraWidgetSnapshot.self, from: data)
        #expect(snapshot.holdings == nil)
        #expect(snapshot.refreshing(with: []).generatedAt == snapshot.generatedAt)
    }

    @Test("A slower overlapping refresh cannot overwrite newer market data")
    func overlappingRefreshes() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = KaraWidgetSnapshotStore(baseURL: directory)
        let cache = KaraWidgetRefreshStore(baseURL: directory)
        let old = Date(timeIntervalSince1970: 1_785_000_000)
        try store.write(KaraWidgetSnapshot(generatedAt: old, quotes: [], portfolio: nil, disclosure: .hidden))
        let loader = KaraWidgetTimelineLoader(store: store) { _ in
            // Another timeline finishes while this request is still in flight.
            _ = try cache.mergeMarket([KaraWidgetMarketQuote(metal: .gold, currency: "EUR", price: 300,
                unitGrams: 10, sourceUpdatedAt: old.addingTimeInterval(7200))], fetchedAt: old.addingTimeInterval(7200))
            return [KaraWidgetMarketQuote(metal: .gold, currency: "EUR", price: 200,
                unitGrams: 10, sourceUpdatedAt: old.addingTimeInterval(3600))]
        }
        let result = await loader.load(now: old.addingTimeInterval(3600))
        #expect(result?.quote(for: .gold)?.ouncePrice == 300)
        #expect(try cache.readMarket().quotes.first?.price == 300)
    }

    @Test("Fresh quotes recover a portfolio that had no usable quote at host publication")
    func recoversUnavailablePortfolio() {
        let snapshot = KaraWidgetSnapshot(generatedAt: .now, quotes: [], portfolio: nil,
            disclosure: .unavailable,
            holdings: [KaraWidgetHolding(metal: .gold, fineWeightGrams: 10, purchaseCost: nil, purchaseCurrency: nil)],
            refreshCoverage: KaraWidgetRefreshCoverage(totalRecordCount: 2, objectCount: 3))
        let result = snapshot.refreshing(with: [KaraWidgetMarketQuote(metal: .gold, currency: "EUR",
            price: 200, unitGrams: 10, sourceUpdatedAt: .now)])
        #expect(result.disclosure == .visible)
        #expect(result.portfolio?.totalValueEUR == 200)
        #expect(result.portfolio?.valuedRecordCount == 1)
        #expect(result.portfolio?.totalRecordCount == 2)
    }

}
