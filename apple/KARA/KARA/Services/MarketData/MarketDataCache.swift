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

nonisolated protocol MarketDataCaching: Sendable {
    func cachedSpot(for pair: SpotPair) async throws -> CachedMarketResource<SpotQuote>?
    func saveSpot(_ entry: CachedMarketResource<SpotQuote>, for pair: SpotPair) async throws
    func cachedMonthly() async throws -> CachedMarketResource<MonthlyDataset>?
    func saveMonthly(_ entry: CachedMarketResource<MonthlyDataset>) async throws
    func cachedManifest() async throws -> CachedMarketResource<MarketManifest>?
    func saveManifest(_ entry: CachedMarketResource<MarketManifest>) async throws
}

nonisolated enum MarketCacheKey: Hashable, Sendable {
    case spot(SpotPair)
    case monthly
    case manifest

    var filename: String {
        switch self {
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

    func cachedSpot(for pair: SpotPair) throws -> CachedMarketResource<SpotQuote>? {
        try read(CachedMarketResource<SpotQuote>.self, for: .spot(pair))
    }

    func saveSpot(_ entry: CachedMarketResource<SpotQuote>, for pair: SpotPair) throws {
        try write(entry, for: .spot(pair))
    }

    func cachedMonthly() throws -> CachedMarketResource<MonthlyDataset>? {
        try read(CachedMarketResource<MonthlyDataset>.self, for: .monthly)
    }

    func saveMonthly(_ entry: CachedMarketResource<MonthlyDataset>) throws {
        try write(entry, for: .monthly)
    }

    func cachedManifest() throws -> CachedMarketResource<MarketManifest>? {
        try read(CachedMarketResource<MarketManifest>.self, for: .manifest)
    }

    func saveManifest(_ entry: CachedMarketResource<MarketManifest>) throws {
        try write(entry, for: .manifest)
    }

    private func read<Value: Codable & Sendable>(
        _ type: CachedMarketResource<Value>.Type,
        for key: MarketCacheKey
    ) throws -> CachedMarketResource<Value>? {
        let fileURL = directory.appending(path: key.filename)
        guard FileManager.default.fileExists(atPath: fileURL.path(percentEncoded: false)) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        return try MarketJSON.decoder.decode(type, from: data)
    }

    private func write<Value: Codable & Sendable>(
        _ entry: CachedMarketResource<Value>,
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
