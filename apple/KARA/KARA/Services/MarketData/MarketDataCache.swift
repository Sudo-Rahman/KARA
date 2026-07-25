import Foundation

nonisolated struct CachedMarketResource<Value: Codable & Sendable>: Codable, Sendable {
    let value: Value
    let etag: String?
    let savedAt: Date

    init(value: Value, etag: String?, savedAt: Date) {
        self.value = value
        self.etag = etag
        self.savedAt = savedAt
    }
}

extension CachedMarketResource: Equatable where Value: Equatable {}

nonisolated struct CachedMonthlyResource: Codable, Equatable, Sendable {
    let value: MonthlyDataset
    let etag: String?
    let dataVersion: String?
    let savedAt: Date

    init(
        value: MonthlyDataset,
        etag: String?,
        dataVersion: String?,
        savedAt: Date
    ) {
        self.value = value
        self.etag = etag
        self.dataVersion = dataVersion
        self.savedAt = savedAt
    }
}

nonisolated protocol MarketDataCaching: Sendable {
    func cachedBootstrap() async throws -> CachedMarketResource<MarketBootstrap>?
    func saveBootstrap(_ entry: CachedMarketResource<MarketBootstrap>) async throws
    func cachedSpot(for pair: SpotPair) async throws -> CachedMarketResource<SpotQuote>?
    func saveSpot(_ entry: CachedMarketResource<SpotQuote>, for pair: SpotPair) async throws
    func cachedMonthly() async throws -> CachedMonthlyResource?
    func saveMonthly(_ entry: CachedMonthlyResource) async throws
    func cachedManifest() async throws -> CachedMarketResource<MarketManifest>?
    func saveManifest(_ entry: CachedMarketResource<MarketManifest>) async throws
}

nonisolated enum MarketCacheKey: Hashable, Sendable {
    case bootstrap
    case spot(SpotPair)
    case monthly
    case manifest

    var filename: String {
        switch self {
        case .bootstrap:
            "market-bootstrap.json"
        case let .spot(pair):
            "spot-\(pair.metal.rawValue)-\(pair.currency.rawValue).json"
        case .monthly:
            "metals-monthly.json"
        case .manifest:
            "manifest.json"
        }
    }
}

actor DiskMarketDataCache: MarketDataCaching {
    private let directory: URL

    init(directory: URL) {
        self.directory = directory
    }

    nonisolated static func applicationSupport() -> DiskMarketDataCache {
        let directory = URL.applicationSupportDirectory
            .appending(path: "KARA", directoryHint: .isDirectory)
            .appending(path: "MarketData", directoryHint: .isDirectory)
        return DiskMarketDataCache(directory: directory)
    }

    func cachedBootstrap() throws -> CachedMarketResource<MarketBootstrap>? {
        try read(CachedMarketResource<MarketBootstrap>.self, for: .bootstrap)
    }

    func saveBootstrap(_ entry: CachedMarketResource<MarketBootstrap>) throws {
        try write(entry, for: .bootstrap)
    }

    func cachedSpot(for pair: SpotPair) throws -> CachedMarketResource<SpotQuote>? {
        try read(CachedMarketResource<SpotQuote>.self, for: .spot(pair))
    }

    func saveSpot(_ entry: CachedMarketResource<SpotQuote>, for pair: SpotPair) throws {
        try write(entry, for: .spot(pair))
    }

    func cachedMonthly() throws -> CachedMonthlyResource? {
        try read(CachedMonthlyResource.self, for: .monthly)
    }

    func saveMonthly(_ entry: CachedMonthlyResource) throws {
        try write(entry, for: .monthly)
    }

    func cachedManifest() throws -> CachedMarketResource<MarketManifest>? {
        try read(CachedMarketResource<MarketManifest>.self, for: .manifest)
    }

    func saveManifest(_ entry: CachedMarketResource<MarketManifest>) throws {
        try write(entry, for: .manifest)
    }

    private func read<Value: Codable & Sendable>(
        _ type: Value.Type,
        for key: MarketCacheKey
    ) throws -> Value? {
        let fileURL = directory.appending(path: key.filename)
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        return try MarketJSON.decoder.decode(type, from: data)
    }

    private func write<Value: Codable & Sendable>(
        _ entry: Value,
        for key: MarketCacheKey
    ) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let data = try MarketJSON.encoder.encode(entry)
        try data.write(to: directory.appending(path: key.filename), options: .atomic)
    }
}
