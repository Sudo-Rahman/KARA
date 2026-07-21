import Foundation
import Observation

nonisolated struct MarketDataStoreErrorState: Error, Equatable, Sendable {
    enum Phase: String, Equatable, Sendable {
        case cache
        case refresh
    }

    let phase: Phase
    let message: String
    let occurredAt: Date
}

@MainActor
@Observable
final class MarketDataStore {
    nonisolated static let defaultPairs = Set(MarketMetal.allCases.map {
        SpotPair(metal: $0, currency: .eur)
    })

    private(set) var spotQuotes: [SpotPair: SpotQuote] = [:]
    private(set) var monthlyDataset: MonthlyDataset?
    private(set) var manifest: MarketManifest?
    private(set) var isRefreshing = false
    private(set) var lastError: MarketDataStoreErrorState?
    private(set) var lastRefreshAt: Date?
    private(set) var spotCachedAt: [SpotPair: Date] = [:]
    private(set) var monthlyCachedAt: Date?

    var marketSnapshot: PortfolioMarketSnapshot {
        PortfolioMarketSnapshot(currentQuotes: spotQuotes, monthly: monthlyDataset)
    }

    var isUsingCachedData: Bool {
        lastError?.phase == .refresh && (!spotQuotes.isEmpty || monthlyDataset != nil)
    }

    @ObservationIgnored private let client: any MarketDataClient
    @ObservationIgnored private let cache: any MarketDataCaching
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private var spotETags: [SpotPair: String] = [:]
    @ObservationIgnored private var monthlyETag: String?
    @ObservationIgnored private var manifestETag: String?

    init(
        client: any MarketDataClient,
        cache: any MarketDataCaching,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.client = client
        self.cache = cache
        self.now = now
    }

    static func live() -> MarketDataStore {
        MarketDataStore(
            client: URLSessionMarketDataClient(),
            cache: DiskMarketDataCache.applicationSupport()
        )
    }

    func quote(for metal: MarketMetal, currency: MarketCurrency = .eur) -> SpotQuote? {
        spotQuotes[SpotPair(metal: metal, currency: currency)]
    }

    func load(pairs: Set<SpotPair> = MarketDataStore.defaultPairs) async {
        await loadCache(pairs: pairs)
        await refresh(pairs: pairs)
    }

    func refresh(pairs: Set<SpotPair> = MarketDataStore.defaultPairs) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        lastError = nil
        defer { isRefreshing = false }

        let client = client
        let cachedSpotETags = spotETags
        let cachedMonthlyETag = monthlyETag
        let cachedManifestETag = manifestETag
        var failures: [MarketDataStoreErrorState] = []

        await withTaskGroup(of: RefreshEvent.self) { group in
            for pair in pairs {
                group.addTask {
                    do {
                        return .spot(
                            pair,
                            try await client.spot(for: pair, etag: cachedSpotETags[pair])
                        )
                    } catch is CancellationError {
                        return .cancelled
                    } catch {
                        return .failed(String(describing: error))
                    }
                }
            }
            group.addTask {
                do {
                    return .monthly(try await client.monthly(etag: cachedMonthlyETag))
                } catch is CancellationError {
                    return .cancelled
                } catch {
                    return .failed(String(describing: error))
                }
            }
            group.addTask {
                do {
                    return .manifest(try await client.manifest(etag: cachedManifestETag))
                } catch is CancellationError {
                    return .cancelled
                } catch {
                    return .failed(String(describing: error))
                }
            }

            for await event in group {
                switch event {
                case let .spot(pair, result):
                    do {
                        try await apply(result, for: pair)
                    } catch {
                        failures.append(errorState(for: error, phase: .cache))
                    }
                case let .monthly(result):
                    do {
                        try await apply(result)
                    } catch {
                        failures.append(errorState(for: error, phase: .cache))
                    }
                case let .manifest(result):
                    do {
                        try await apply(result)
                    } catch {
                        failures.append(errorState(for: error, phase: .cache))
                    }
                case let .failed(message):
                    failures.append(MarketDataStoreErrorState(
                        phase: .refresh,
                        message: message,
                        occurredAt: now()
                    ))
                case .cancelled:
                    break
                }
            }
        }

        guard !Task.isCancelled else { return }
        lastRefreshAt = now()
        lastError = failures.first
    }

    private func loadCache(pairs: Set<SpotPair>) async {
        var cacheFailure: MarketDataStoreErrorState?
        for pair in pairs {
            do {
                if let entry = try await cache.cachedSpot(for: pair) {
                    spotQuotes[pair] = entry.value
                    spotCachedAt[pair] = entry.savedAt
                    spotETags[pair] = entry.etag
                }
            } catch {
                cacheFailure = errorState(for: error, phase: .cache)
            }
        }
        do {
            if let entry = try await cache.cachedMonthly() {
                monthlyDataset = entry.value
                monthlyCachedAt = entry.savedAt
                monthlyETag = entry.etag
            }
        } catch {
            cacheFailure = errorState(for: error, phase: .cache)
        }
        do {
            if let entry = try await cache.cachedManifest() {
                manifest = entry.value
                manifestETag = entry.etag
            }
        } catch {
            cacheFailure = errorState(for: error, phase: .cache)
        }
        lastError = cacheFailure
    }

    private func apply(
        _ result: MarketFetchResult<SpotQuote>,
        for pair: SpotPair
    ) async throws {
        switch result {
        case let .modified(quote, etag):
            let timestamp = now()
            spotQuotes[pair] = quote
            spotCachedAt[pair] = timestamp
            spotETags[pair] = etag
            try await cache.saveSpot(
                CachedMarketResource(value: quote, etag: etag, savedAt: timestamp),
                for: pair
            )
        case let .notModified(etag):
            if let etag { spotETags[pair] = etag }
        }
    }

    private func apply(_ result: MarketFetchResult<MonthlyDataset>) async throws {
        switch result {
        case let .modified(dataset, etag):
            let timestamp = now()
            monthlyDataset = dataset
            monthlyCachedAt = timestamp
            monthlyETag = etag
            try await cache.saveMonthly(
                CachedMarketResource(value: dataset, etag: etag, savedAt: timestamp)
            )
        case let .notModified(etag):
            if let etag { monthlyETag = etag }
        }
    }

    private func apply(_ result: MarketFetchResult<MarketManifest>) async throws {
        switch result {
        case let .modified(value, etag):
            let timestamp = now()
            manifest = value
            manifestETag = etag
            try await cache.saveManifest(
                CachedMarketResource(value: value, etag: etag, savedAt: timestamp)
            )
        case let .notModified(etag):
            if let etag { manifestETag = etag }
        }
    }

    private func errorState(
        for error: any Error,
        phase: MarketDataStoreErrorState.Phase
    ) -> MarketDataStoreErrorState {
        MarketDataStoreErrorState(
            phase: phase,
            message: String(describing: error),
            occurredAt: now()
        )
    }
}

private nonisolated enum RefreshEvent: Sendable {
    case spot(SpotPair, MarketFetchResult<SpotQuote>)
    case monthly(MarketFetchResult<MonthlyDataset>)
    case manifest(MarketFetchResult<MarketManifest>)
    case failed(String)
    case cancelled
}
