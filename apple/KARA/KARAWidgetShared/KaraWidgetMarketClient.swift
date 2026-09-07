import Foundation

nonisolated struct KaraWidgetMarketClient: Sendable {
    let store: KaraWidgetRefreshStore
    let session: URLSession

    init(store: KaraWidgetRefreshStore, session: URLSession = .shared) {
        self.store = store
        self.session = session
    }

    func quotes(currencies: [String]) async throws -> [KaraWidgetMarketQuote] {
        let access = try store.readAccess()
        guard access.baseURL.scheme == "https" || access.baseURL.host == "127.0.0.1" else {
            throw URLError(.badURL)
        }
        var url = URLComponents(url: access.baseURL.appending(path: "widget/v1/quotes.json"), resolvingAgainstBaseURL: false)!
        url.queryItems = [URLQueryItem(name: "currencies", value: currencies.sorted().joined(separator: ","))]
        var request = URLRequest(url: url.url!)
        request.timeoutInterval = 15
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer \(access.token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard payload.schemaVersion == 1 else { throw URLError(.cannotParseResponse) }
        let quotes = try payload.spots.map { try $0.quote() }
        let expected = Set(currencies).union(["EUR"])
        guard quotes.count == expected.count * KaraWidgetMetal.allCases.count,
              Set(quotes.map { "\($0.metal.rawValue):\($0.currency)" }).count == quotes.count,
              quotes.allSatisfy({ expected.contains($0.currency) }) else {
            throw URLError(.cannotParseResponse)
        }
        return quotes
    }

    private struct Payload: Decodable {
        let schemaVersion: Int
        let spots: [Spot]
    }
    private struct Spot: Decodable {
        struct Unit: Decodable { let code: String; let grams: String }
        let schemaVersion: Int
        let metal: KaraWidgetMetal
        let currency: String
        let price: String
        let unit: Unit
        let sourceUpdatedAt: String

        func quote() throws -> KaraWidgetMarketQuote {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var date = formatter.date(from: sourceUpdatedAt)
            if date == nil {
                formatter.formatOptions = [.withInternetDateTime]
                date = formatter.date(from: sourceUpdatedAt)
            }
            guard schemaVersion == 1, unit.code == "troy_ounce",
                  let price = Decimal(string: price, locale: Locale(identifier: "en_US_POSIX")),
                  let grams = Decimal(string: unit.grams, locale: Locale(identifier: "en_US_POSIX")),
                  price.isFinite, price > 0, grams.isFinite, grams > 0, let date else {
                throw URLError(.cannotParseResponse)
            }
            return KaraWidgetMarketQuote(metal: metal, currency: currency, price: price,
                unitGrams: grams, sourceUpdatedAt: date)
        }
    }
}
