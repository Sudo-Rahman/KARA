import Foundation
import Testing
@testable import KARA

@Suite("Widget network access", .serialized)
struct KaraWidgetMarketClientTests {
    @Test("The extension uses its scoped credential and decodes all four source quotes")
    func fetchesWithoutAppAttest() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = KaraWidgetRefreshStore(baseURL: directory)
        try store.writeAccess(KaraWidgetAccess(baseURL: URL(string: "https://example.test")!, token: "widget-token"))
        WidgetNetworkStub.handler = { request in
            #expect(request.url?.path == "/widget/v1/quotes.json")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer widget-token")
            #expect(request.value(forHTTPHeaderField: "X-Kara-App-Attest-Key-Id") == nil)
            let spots = KaraWidgetMetal.allCases.map { metal in
                #"{"schemaVersion":1,"metal":""# + metal.rawValue + #"","currency":"EUR","price":"3558.900966","unit":{"code":"troy_ounce","grams":"31.1034768"},"sourceUpdatedAt":"2026-09-07T09:45:33.123Z"}"#
            }.joined(separator: ",")
            return (200, Data((#"{"schemaVersion":1,"spots":["# + spots + "]}").utf8))
        }
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let quotes = try await KaraWidgetMarketClient(store: store, session: session).quotes(currencies: ["EUR"])
        #expect(quotes.count == 4)
        #expect(quotes.first?.price == Decimal(string: "3558.900966"))
        #expect(quotes.first?.sourceUpdatedAt == Date(timeIntervalSince1970: 1_788_774_333.123))
    }

    @Test("Rejected credentials and incomplete payloads are errors, not fresh data", arguments: [401, 503, 200])
    func rejectsBadResponse(status: Int) async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = KaraWidgetRefreshStore(baseURL: directory)
        try store.writeAccess(KaraWidgetAccess(baseURL: URL(string: "https://example.test")!, token: "widget-token"))
        WidgetNetworkStub.handler = { _ in (status, Data(#"{"schemaVersion":1,"spots":[]}"#.utf8)) }
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        await #expect(throws: (any Error).self) {
            try await KaraWidgetMarketClient(store: store, session: session).quotes(currencies: ["EUR"])
        }
    }

    private func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [WidgetNetworkStub.self]
        return URLSession(configuration: config)
    }
}

private final class WidgetNetworkStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let (status, data) = try Self.handler?(request),
                  let response = HTTPURLResponse(url: request.url!, statusCode: status,
                    httpVersion: "HTTP/1.1", headerFields: nil) else { throw URLError(.badServerResponse) }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }
    override func stopLoading() {}
}
