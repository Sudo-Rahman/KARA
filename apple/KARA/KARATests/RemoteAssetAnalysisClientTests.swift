import Foundation
import Testing
@testable import KARA

@Suite("Remote asset analysis client")
struct RemoteAssetAnalysisClientTests {
    @Test("Posts the JPEG as an attested binary request and decodes schema v1")
    func postsPhotoAndDecodesStrictResponse() async throws {
        let photo = Data([0xFF, 0xD8, 0xFF, 0xD9])
        let transport = RecordingAnalysisTransport(
            statusCode: 200,
            body: Self.validResponse
        )
        let client = RemoteAssetAnalysisClient(
            baseURL: URL(string: "https://kara.test")!,
            transport: transport
        )

        let suggestion = try await client.analyze(
            kind: .objectPhoto,
            data: photo,
            locale: Locale(identifier: "fr_FR")
        )

        #expect(suggestion.name == "Lingotin 10 g")
        #expect(suggestion.category == .bar)
        #expect(suggestion.serialNumber == "00-AbC-42")
        #expect(suggestion.pricePaidMinorUnits == 239_001)
        let request = try #require(await transport.lastRequest())
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/v1/asset-extraction")
        #expect(request.url?.query?.contains("kind=object-photo") == true)
        #expect(request.url?.query?.contains("locale=fr-FR") == true)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "image/jpeg")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Content-Length") == String(photo.count))
        #expect(request.httpBody == photo)
    }

    @Test("Autoupdating locales are sent as valid BCP-47 identifiers")
    func normalizesAutoupdatingLocale() async throws {
        let transport = RecordingAnalysisTransport(
            statusCode: 200,
            body: Self.validResponse
        )
        let client = RemoteAssetAnalysisClient(
            baseURL: URL(string: "https://kara.test")!,
            transport: transport
        )

        _ = try await client.analyze(
            kind: .objectPhoto,
            data: Data([0xFF, 0xD8, 0xFF, 0xD9]),
            locale: .autoupdatingCurrent
        )

        let request = try #require(await transport.lastRequest())
        let url = try #require(request.url)
        let components = try #require(
            URLComponents(url: url, resolvingAgainstBaseURL: false)
        )
        let locale = try #require(
            components.queryItems?.first(where: { $0.name == "locale" })?.value
        )
        #expect(locale == Locale(identifier: locale).identifier(.bcp47))
        #expect(!locale.contains("_"))
    }

    @Test("Missing or additional response properties are rejected")
    func responseShapeIsStrict() async throws {
        var missingRoot = try #require(
            JSONSerialization.jsonObject(with: Self.validResponse) as? [String: Any]
        )
        var missingSuggestion = try #require(missingRoot["suggestion"] as? [String: Any])
        missingSuggestion.removeValue(forKey: "serialNumber")
        missingRoot["suggestion"] = missingSuggestion

        let missingClient = RemoteAssetAnalysisClient(
            baseURL: URL(string: "https://kara.test")!,
            transport: RecordingAnalysisTransport(
                statusCode: 200,
                body: try JSONSerialization.data(withJSONObject: missingRoot)
            )
        )
        await #expect(throws: AssetAnalysisError.invalidResponse) {
            try await missingClient.analyze(
                kind: .objectPhoto,
                data: Data([0x01]),
                locale: Locale(identifier: "fr_FR")
            )
        }

        var additionalRoot = try #require(
            JSONSerialization.jsonObject(with: Self.validResponse) as? [String: Any]
        )
        additionalRoot["unexpected"] = true
        let additionalClient = RemoteAssetAnalysisClient(
            baseURL: URL(string: "https://kara.test")!,
            transport: RecordingAnalysisTransport(
                statusCode: 200,
                body: try JSONSerialization.data(withJSONObject: additionalRoot)
            )
        )
        await #expect(throws: AssetAnalysisError.invalidResponse) {
            try await additionalClient.analyze(
                kind: .objectPhoto,
                data: Data([0x01]),
                locale: Locale(identifier: "fr_FR")
            )
        }
    }

    @Test("Preset properties must remain semantically consistent")
    func contradictoryPresetPropertiesAreRejected() async throws {
        var root = try #require(
            JSONSerialization.jsonObject(with: Self.validResponse) as? [String: Any]
        )
        var suggestion = try #require(root["suggestion"] as? [String: Any])
        suggestion["category"] = "coin"
        root["suggestion"] = suggestion

        let client = RemoteAssetAnalysisClient(
            baseURL: URL(string: "https://kara.test")!,
            transport: RecordingAnalysisTransport(
                statusCode: 200,
                body: try JSONSerialization.data(withJSONObject: root)
            )
        )

        await #expect(throws: AssetAnalysisError.invalidResponse) {
            try await client.analyze(
                kind: .objectPhoto,
                data: Data([0x01]),
                locale: Locale(identifier: "fr_FR")
            )
        }
    }

    @Test("Rounded visible measurements remain compatible with a preset")
    func roundedPresetMeasurementsAreAccepted() async throws {
        var root = try #require(
            JSONSerialization.jsonObject(with: Self.validResponse) as? [String: Any]
        )
        var suggestion = try #require(root["suggestion"] as? [String: Any])
        suggestion["name"] = "Lingotin or 1 oz"
        suggestion["presetId"] = "gold-bar-1oz"
        suggestion["weightGrams"] = 31.1
        root["suggestion"] = suggestion

        let client = RemoteAssetAnalysisClient(
            baseURL: URL(string: "https://kara.test")!,
            transport: RecordingAnalysisTransport(
                statusCode: 200,
                body: try JSONSerialization.data(withJSONObject: root)
            )
        )

        let result = try await client.analyze(
            kind: .objectPhoto,
            data: Data([0x01]),
            locale: Locale(identifier: "fr_FR")
        )
        #expect(result.presetID == "gold-bar-1oz")
        #expect(result.weightGrams == 31.1)
    }

    @Test("Stable backend error codes become user-facing analysis errors")
    func backendErrorsAreMapped() async {
        let body = Data(#"{"error":{"code":"ANALYSIS_QUARANTINED"}}"#.utf8)
        let client = RemoteAssetAnalysisClient(
            baseURL: URL(string: "https://kara.test")!,
            transport: RecordingAnalysisTransport(statusCode: 429, body: body)
        )

        await #expect(throws: AssetAnalysisError.quarantined) {
            try await client.analyze(
                kind: .invoice,
                data: Data([0x25, 0x50, 0x44, 0x46]),
                locale: Locale(identifier: "en_US")
            )
        }
    }

    private static let validResponse = Data(#"""
    {
      "schemaVersion": 1,
      "suggestion": {
        "name": "Lingotin 10 g",
        "category": "bar",
        "presetId": "gold-bar-10g",
        "quantity": 1,
        "purchaseDate": "2024-05-14",
        "metal": "gold",
        "weightGrams": 10,
        "metalKarat": 24,
        "finenessPermille": 999.9,
        "gemstoneCaratWeight": null,
        "gemstoneClarity": null,
        "pricePaidMinorUnits": 239001,
        "currencyCode": "EUR",
        "sellerName": "Maison Lemoine",
        "storageLocationName": null,
        "invoiceNumber": "ML-42",
        "serialNumber": "00-AbC-42"
      }
    }
    """#.utf8)
}

private actor RecordingAnalysisTransport: APIDataTransport {
    private let statusCode: Int
    private let body: Data
    private var request: URLRequest?

    init(statusCode: Int, body: Data) {
        self.statusCode = statusCode
        self.body = body
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        self.request = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        return (body, response)
    }

    func lastRequest() -> URLRequest? { request }
}
