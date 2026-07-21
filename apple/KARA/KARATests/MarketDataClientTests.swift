import Foundation
import Testing
@testable import KARA

@Suite("Market data client", .serialized)
struct MarketDataClientTests {
    @Test("Spot requests send only metal and currency and decode a validated quote")
    func fetchesSpotQuote() async throws {
        let session = URLSession.stubbed { request in
            let url = try #require(request.url)
            let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
            #expect(components.path == "/v1/metals-spot.json")
            #expect(Set(components.queryItems ?? []) == Set([
                URLQueryItem(name: "metal", value: "XAU"),
                URLQueryItem(name: "currency", value: "EUR"),
            ]))
            let payload = Data(#"{"schemaVersion":1,"metal":"XAU","currency":"EUR","price":"3558.900966","unit":{"code":"troy_ounce","grams":"31.1034768"},"sourceUpdatedAt":"2026-07-21T09:45:33Z"}"#.utf8)
            return try HTTPStubResponse(status: 200, headers: ["ETag": "fresh-tag"], body: payload)
        }
        let client = URLSessionMarketDataClient(
            baseURL: URL(string: "https://example.test")!,
            session: session
        )

        let result = try await client.spot(for: SpotPair(metal: .gold, currency: .eur), etag: nil)

        guard case let .modified(quote, etag) = result else {
            Issue.record("Expected a modified quote")
            return
        }
        #expect(quote.price == Decimal(string: "3558.900966"))
        #expect(etag == "fresh-tag")
    }

    @Test("Cached resources revalidate with If-None-Match and accept 304")
    func revalidatesWithETag() async throws {
        let session = URLSession.stubbed { request in
            #expect(request.value(forHTTPHeaderField: "If-None-Match") == "cached-tag")
            return try HTTPStubResponse(status: 304, headers: ["ETag": "cached-tag"])
        }
        let client = URLSessionMarketDataClient(
            baseURL: URL(string: "https://example.test")!,
            session: session
        )

        let result = try await client.monthly(etag: "cached-tag")

        guard case let .notModified(etag) = result else {
            Issue.record("Expected a not-modified response")
            return
        }
        #expect(etag == "cached-tag")
    }

    @Test("HTTP failures are surfaced without decoding a fabricated value", arguments: [400, 502])
    func rejectsHTTPFailures(status: Int) async throws {
        let session = URLSession.stubbed { _ in
            try HTTPStubResponse(status: status)
        }
        let client = URLSessionMarketDataClient(
            baseURL: URL(string: "https://example.test")!,
            session: session
        )

        do {
            _ = try await client.spot(for: SpotPair(metal: .gold, currency: .eur), etag: nil)
            Issue.record("Expected HTTP \(status) to fail")
        } catch let error as MarketDataClientError {
            #expect(error == .httpStatus(status))
        }
    }

    @Test("A spot response for a different pair is rejected")
    func rejectsMismatchedSpotPair() async throws {
        let session = URLSession.stubbed { _ in
            let payload = Data(#"{"schemaVersion":1,"metal":"XAG","currency":"EUR","price":"80.12","unit":{"code":"troy_ounce","grams":"31.1034768"},"sourceUpdatedAt":"2026-07-21T09:45:33Z"}"#.utf8)
            return try HTTPStubResponse(status: 200, body: payload)
        }
        let requested = SpotPair(metal: .gold, currency: .eur)
        let received = SpotPair(metal: .silver, currency: .eur)
        let client = URLSessionMarketDataClient(
            baseURL: URL(string: "https://example.test")!,
            session: session
        )

        do {
            _ = try await client.spot(for: requested, etag: nil)
            Issue.record("Expected the mismatched payload to fail")
        } catch let error as MarketPayloadError {
            #expect(error == .unexpectedSpotPair(expected: requested, received: received))
        }
    }
}

private struct HTTPStubResponse: Sendable {
    let response: HTTPURLResponse
    let body: Data

    init(status: Int, headers: [String: String] = [:], body: Data = Data()) throws {
        self.response = try #require(HTTPURLResponse(
            url: URL(string: "https://example.test")!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        ))
        self.body = body
    }
}

private final class MarketURLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> HTTPStubResponse)?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let result = try Self.handler?(request)
            guard let result else { throw URLError(.badServerResponse) }
            client?.urlProtocol(self, didReceive: result.response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: result.body)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension URLSession {
    static func stubbed(
        handler: @escaping @Sendable (URLRequest) throws -> HTTPStubResponse
    ) -> URLSession {
        MarketURLProtocolStub.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MarketURLProtocolStub.self]
        return URLSession(configuration: configuration)
    }
}
