import Foundation

nonisolated struct KaraWidgetAccess: Codable, Sendable {
    let baseURL: URL
    let token: String
}

nonisolated struct KaraWidgetMarketCache: Codable, Sendable {
    let fetchedAt: Date
    let quotes: [KaraWidgetMarketQuote]
}

/// Separate files keep the extension from overwriting host-owned holdings or privacy state.
nonisolated struct KaraWidgetRefreshStore: Sendable {
    let baseURL: URL

    func readAccess() throws -> KaraWidgetAccess {
        try read(KaraWidgetAccess.self, name: "access")
    }
    func writeAccess(_ access: KaraWidgetAccess) throws {
        try write(access, name: "access")
    }
    func readMarket() throws -> KaraWidgetMarketCache {
        try read(KaraWidgetMarketCache.self, name: "market")
    }
    func writeMarket(_ cache: KaraWidgetMarketCache) throws {
        try write(cache, name: "market")
    }
    func mergeMarket(_ quotes: [KaraWidgetMarketQuote], fetchedAt: Date) throws -> KaraWidgetMarketCache {
        let target = url("market")
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        var coordinationError: NSError?
        var result: Result<KaraWidgetMarketCache, Error>?
        NSFileCoordinator().coordinate(writingItemAt: target, options: .forMerging, error: &coordinationError) { _ in
            result = Result {
                let existing = try? readMarket()
                var merged = existing?.quotes ?? []
                for quote in quotes {
                    if let index = merged.firstIndex(where: { $0.metal == quote.metal && $0.currency == quote.currency }) {
                        if quote.sourceUpdatedAt >= merged[index].sourceUpdatedAt { merged[index] = quote }
                    } else {
                        merged.append(quote)
                    }
                }
                let cache = KaraWidgetMarketCache(fetchedAt: max(existing?.fetchedAt ?? fetchedAt, fetchedAt), quotes: merged)
                try writeMarket(cache)
                return cache
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CocoaError(.fileWriteUnknown) }
        return try result.get()
    }

    private func url(_ name: String) -> URL {
        baseURL.appending(path: "Widget/v1/\(name).json")
    }
    private func read<T: Decodable>(_ type: T.Type, name: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(contentsOf: url(name)))
    }
    private func write<T: Encodable>(_ value: T, name: String) throws {
        let target = url(name)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(value)
#if os(iOS)
        try data.write(to: target, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
#else
        try data.write(to: target, options: .atomic)
#endif
    }
}
