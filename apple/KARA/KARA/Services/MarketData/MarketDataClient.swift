import Foundation

nonisolated enum MarketFetchResult<Value: Sendable>: Sendable {
    case modified(Value, etag: String?)
    case notModified(etag: String?)
}

nonisolated protocol MarketDataClient: Sendable {
    func spot(for pair: SpotPair, etag: String?) async throws -> MarketFetchResult<SpotQuote>
    func monthly(etag: String?) async throws -> MarketFetchResult<MonthlyDataset>
    func manifest(etag: String?) async throws -> MarketFetchResult<MarketManifest>
}

nonisolated enum MarketDataClientError: Error, Equatable, Sendable {
    case invalidURL
    case nonHTTPResponse
    case httpStatus(Int)
}

nonisolated final class URLSessionMarketDataClient: MarketDataClient, @unchecked Sendable {
    static let productionBaseURL = URL(string: "https://kara.rahman-dev.ovh")!

    private let baseURL: URL
    private let session: URLSession

    init(
        baseURL: URL = URLSessionMarketDataClient.productionBaseURL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    func spot(for pair: SpotPair, etag: String?) async throws -> MarketFetchResult<SpotQuote> {
        let endpoint = baseURL.appending(path: "v1/metals-spot.json")
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw MarketDataClientError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "metal", value: pair.metal.rawValue),
            URLQueryItem(name: "currency", value: pair.currency.rawValue),
        ]
        guard let url = components.url else {
            throw MarketDataClientError.invalidURL
        }
        let response = try await fetch(url: url, etag: etag)
        switch response {
        case let .modified(data, responseETag):
            let quote = try MarketJSON.decoder.decode(SpotQuote.self, from: data).validated(for: pair)
            return .modified(quote, etag: responseETag)
        case let .notModified(responseETag):
            return .notModified(etag: responseETag)
        }
    }

    func monthly(etag: String?) async throws -> MarketFetchResult<MonthlyDataset> {
        let response = try await fetch(
            url: baseURL.appending(path: "v1/metals-monthly.json"),
            etag: etag
        )
        switch response {
        case let .modified(data, responseETag):
            let dataset = try MarketJSON.decoder.decode(MonthlyDataset.self, from: data).validated()
            return .modified(dataset, etag: responseETag)
        case let .notModified(responseETag):
            return .notModified(etag: responseETag)
        }
    }

    func manifest(etag: String?) async throws -> MarketFetchResult<MarketManifest> {
        let response = try await fetch(
            url: baseURL.appending(path: "v1/manifest.json"),
            etag: etag
        )
        switch response {
        case let .modified(data, responseETag):
            let manifest = try MarketJSON.decoder.decode(MarketManifest.self, from: data).validated()
            return .modified(manifest, etag: responseETag)
        case let .notModified(responseETag):
            return .notModified(etag: responseETag)
        }
    }

    private func fetch(url: URL, etag: String?) async throws -> RawFetchResult {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let etag, !etag.isEmpty {
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw MarketDataClientError.nonHTTPResponse
        }
        let responseETag = httpResponse.value(forHTTPHeaderField: "ETag")
        switch httpResponse.statusCode {
        case 200:
            return .modified(data, etag: responseETag)
        case 304:
            return .notModified(etag: responseETag)
        default:
            throw MarketDataClientError.httpStatus(httpResponse.statusCode)
        }
    }
}

private nonisolated enum RawFetchResult: Sendable {
    case modified(Data, etag: String?)
    case notModified(etag: String?)
}
