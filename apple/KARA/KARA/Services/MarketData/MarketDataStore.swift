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

nonisolated enum MarketDataStoreRefreshError: Error, Equatable, Sendable {
    case missingCachedBootstrap
    case missingCachedMonthly
    case monthlyVersionMismatch(expected: String, receivedETag: String?)
}

@MainActor
@Observable
final class MarketDataStore {
    nonisolated static let defaultPairs = Set(MarketBootstrap.expectedPairs)

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
    @ObservationIgnored private var bootstrapETag: String?
    @ObservationIgnored private var spotETags: [SpotPair: String] = [:]
    @ObservationIgnored private var monthlyETag: String?
    @ObservationIgnored private var monthlyDataVersion: String?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var activeRefreshPairs: Set<SpotPair>?
    @ObservationIgnored private var pendingRefreshPairs: Set<SpotPair>?

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
        guard !Task.isCancelled else { return }
        await refresh(pairs: pairs)
    }

    func refresh(pairs: Set<SpotPair> = MarketDataStore.defaultPairs) async {
        if let refreshTask {
            pendingRefreshPairs = pairs == activeRefreshPairs ? nil : pairs
            await refreshTask.value
            return
        }

        pendingRefreshPairs = pairs
        let task = Task<Void, Never> { @MainActor [weak self] in
            guard let self else { return }
            await self.runRefreshLoop()
        }
        refreshTask = task
        await task.value
    }

    private func runRefreshLoop() async {
        isRefreshing = true
        defer {
            activeRefreshPairs = nil
            refreshTask = nil
            isRefreshing = false
        }

        while let pairs = pendingRefreshPairs {
            pendingRefreshPairs = nil
            activeRefreshPairs = pairs
            await performRefresh(pairs: pairs)
        }
    }

    private func performRefresh(pairs: Set<SpotPair>) async {
        lastError = nil

        do {
            let currentManifest = try await refreshBootstrap(etag: bootstrapETag)
            guard !Task.isCancelled else { return }
            var failures = await refreshAdditionalSpots(
                pairs.subtracting(Self.defaultPairs)
            )

            if monthlyDataset == nil || monthlyDataVersion != currentManifest.dataVersion {
                do {
                    try await refreshMonthly(
                        expectedVersion: currentManifest.dataVersion,
                        canRecoverPublicationRace: true
                    )
                } catch is CancellationError {
                    return
                } catch {
                    failures.append(errorState(for: error, phase: .refresh))
                }
            }

            guard !Task.isCancelled else { return }
            lastRefreshAt = now()
            lastError = failures.first
        } catch is CancellationError {
            return
        } catch {
            lastRefreshAt = now()
            lastError = errorState(for: error, phase: .refresh)
        }
    }

    private func loadCache(pairs: Set<SpotPair>) async {
        var cacheFailure: MarketDataStoreErrorState?

        do {
            if let entry = try await cache.cachedBootstrap() {
                let bootstrap = try entry.value.validated()
                publish(bootstrap, cachedAt: entry.savedAt)
                bootstrapETag = entry.etag
            } else {
                try await loadLegacyBootstrapCache()
            }
        } catch {
            cacheFailure = errorState(for: error, phase: .cache)
        }

        do {
            if let entry = try await cache.cachedMonthly() {
                monthlyDataset = try entry.value.validated()
                monthlyCachedAt = entry.savedAt
                monthlyETag = entry.etag
                monthlyDataVersion = entry.dataVersion
            }
        } catch {
            cacheFailure = errorState(for: error, phase: .cache)
        }

        for pair in pairs.subtracting(Self.defaultPairs) {
            do {
                if let entry = try await cache.cachedSpot(for: pair) {
                    spotQuotes[pair] = try entry.value.validated(for: pair)
                    spotCachedAt[pair] = entry.savedAt
                    spotETags[pair] = entry.etag
                }
            } catch {
                cacheFailure = errorState(for: error, phase: .cache)
            }
        }

        lastError = cacheFailure
    }

    private func loadLegacyBootstrapCache() async throws {
        if let entry = try await cache.cachedManifest() {
            manifest = try entry.value.validated()
        }
        for pair in Self.defaultPairs {
            if let entry = try await cache.cachedSpot(for: pair) {
                spotQuotes[pair] = try entry.value.validated(for: pair)
                spotCachedAt[pair] = entry.savedAt
            }
        }
    }

    private func refreshBootstrap(etag: String?) async throws -> MarketManifest {
        switch try await client.bootstrap(etag: etag) {
        case let .modified(value, responseETag):
            let bootstrap = try value.validated()
            let timestamp = now()
            try await cache.saveBootstrap(CachedMarketResource(
                value: bootstrap,
                etag: responseETag,
                savedAt: timestamp
            ))
            bootstrapETag = responseETag
            publish(bootstrap, cachedAt: timestamp)
            return bootstrap.manifest

        case let .notModified(responseETag):
            if let responseETag {
                bootstrapETag = responseETag
            }
            guard let manifest else {
                throw MarketDataStoreRefreshError.missingCachedBootstrap
            }
            return manifest
        }
    }

    private func publish(_ bootstrap: MarketBootstrap, cachedAt: Date) {
        manifest = bootstrap.manifest
        for pair in Self.defaultPairs {
            spotQuotes.removeValue(forKey: pair)
            spotCachedAt.removeValue(forKey: pair)
        }
        for quote in bootstrap.spots {
            spotQuotes[quote.id] = quote
            spotCachedAt[quote.id] = cachedAt
        }
    }

    private func refreshAdditionalSpots(
        _ pairs: Set<SpotPair>
    ) async -> [MarketDataStoreErrorState] {
        guard !pairs.isEmpty else { return [] }
        let client = client
        let cachedETags = spotETags
        var failures: [MarketDataStoreErrorState] = []

        await withTaskGroup(of: AdditionalSpotRefreshEvent.self) { group in
            for pair in pairs {
                group.addTask {
                    do {
                        return .spot(
                            pair,
                            try await client.spot(for: pair, etag: cachedETags[pair])
                        )
                    } catch is CancellationError {
                        return .cancelled
                    } catch {
                        return .failed(String(describing: error))
                    }
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
        return failures
    }

    private func apply(
        _ result: MarketFetchResult<SpotQuote>,
        for pair: SpotPair
    ) async throws {
        switch result {
        case let .modified(quote, etag):
            let validatedQuote = try quote.validated(for: pair)
            let timestamp = now()
            spotQuotes[pair] = validatedQuote
            spotCachedAt[pair] = timestamp
            spotETags[pair] = etag
            try await cache.saveSpot(
                CachedMarketResource(value: validatedQuote, etag: etag, savedAt: timestamp),
                for: pair
            )
        case let .notModified(etag):
            if let etag { spotETags[pair] = etag }
        }
    }

    private func refreshMonthly(
        expectedVersion: String,
        canRecoverPublicationRace: Bool
    ) async throws {
        let result = try await client.monthly(etag: monthlyETag)
        guard !Task.isCancelled else { throw CancellationError() }

        switch result {
        case let .modified(dataset, responseETag):
            guard etag(responseETag, matchesDataVersion: expectedVersion) else {
                try await recoverPublicationRace(
                    expectedVersion: expectedVersion,
                    receivedETag: responseETag,
                    allowed: canRecoverPublicationRace
                )
                return
            }
            try await saveMonthly(
                dataset: try dataset.validated(),
                etag: responseETag,
                dataVersion: expectedVersion
            )

        case let .notModified(responseETag):
            let effectiveETag = responseETag ?? monthlyETag
            guard let monthlyDataset else {
                throw MarketDataStoreRefreshError.missingCachedMonthly
            }
            guard etag(effectiveETag, matchesDataVersion: expectedVersion) else {
                try await recoverPublicationRace(
                    expectedVersion: expectedVersion,
                    receivedETag: effectiveETag,
                    allowed: canRecoverPublicationRace
                )
                return
            }
            try await saveMonthly(
                dataset: monthlyDataset,
                etag: effectiveETag,
                dataVersion: expectedVersion
            )
        }
    }

    private func recoverPublicationRace(
        expectedVersion: String,
        receivedETag: String?,
        allowed: Bool
    ) async throws {
        guard allowed else {
            throw MarketDataStoreRefreshError.monthlyVersionMismatch(
                expected: expectedVersion,
                receivedETag: receivedETag
            )
        }
        let latestManifest = try await refreshBootstrap(etag: nil)
        try await refreshMonthly(
            expectedVersion: latestManifest.dataVersion,
            canRecoverPublicationRace: false
        )
    }

    private func saveMonthly(
        dataset: MonthlyDataset,
        etag: String?,
        dataVersion: String
    ) async throws {
        let timestamp = now()
        let entry = CachedMonthlyResource(
            value: dataset,
            etag: etag,
            dataVersion: dataVersion,
            savedAt: timestamp
        )
        try await cache.saveMonthly(entry)
        monthlyDataset = dataset
        monthlyCachedAt = timestamp
        monthlyETag = etag
        monthlyDataVersion = dataVersion
    }

    private func etag(_ etag: String?, matchesDataVersion dataVersion: String) -> Bool {
        guard var value = etag?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return false
        }
        if value.hasPrefix("W/") {
            value.removeFirst(2)
        }
        if value.first == "\"", value.last == "\"", value.count >= 2 {
            value.removeFirst()
            value.removeLast()
        }
        return value == dataVersion
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

private nonisolated enum AdditionalSpotRefreshEvent: Sendable {
    case spot(SpotPair, MarketFetchResult<SpotQuote>)
    case failed(String)
    case cancelled
}
