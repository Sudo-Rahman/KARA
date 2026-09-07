import Foundation

nonisolated struct KaraWidgetTimelineLoader: Sendable {
    let store: KaraWidgetSnapshotStore
    let fetch: @Sendable ([String]) async throws -> [KaraWidgetMarketQuote]

    func load(now: Date = .now) async -> KaraWidgetSnapshot? {
        let cache = KaraWidgetRefreshStore(baseURL: store.baseURL)
        let initial = try? store.read()
        let currencies = Set(initial?.holdings?.compactMap(\.purchaseCurrency) ?? []).union(["EUR"])
        var market = try? cache.readMarket()
        let cachedCurrencies = Set(market?.quotes.map(\.currency) ?? [])
        if market == nil || now.timeIntervalSince(market!.fetchedAt) >= 15 * 60
            || !currencies.isSubset(of: cachedCurrencies) {
            do {
                let quotes = try await fetch(Array(currencies))
                try Task.checkCancellation()
                guard quotes.allSatisfy({ $0.price.isFinite && $0.price > 0 && $0.unitGrams.isFinite && $0.unitGrams > 0 }) else {
                    throw URLError(.cannotParseResponse)
                }
                // Coordinate reread/merge/write across overlapping extension processes.
                market = (try? cache.mergeMarket(quotes, fetchedAt: now))
                    ?? KaraWidgetMarketCache(fetchedAt: now, quotes: quotes)
            } catch {
                // A failed request never advances the market source timestamps.
            }
        }
        // The host can change holdings or enable masking while the request is in flight.
        guard let latest = try? store.read() else { return nil }
        return latest.refreshing(with: market?.quotes ?? [])
    }
}

nonisolated struct KaraWidgetMarketQuote: Codable, Equatable, Sendable {
    let metal: KaraWidgetMetal
    let currency: String
    let price: Decimal
    let unitGrams: Decimal
    let sourceUpdatedAt: Date
}
