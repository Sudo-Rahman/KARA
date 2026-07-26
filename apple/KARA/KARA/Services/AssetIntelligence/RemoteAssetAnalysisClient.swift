import Foundation

nonisolated enum AssetExtractionKind: String, Sendable {
    case objectPhoto = "object-photo"
    case invoice

    var contentType: String {
        switch self {
        case .objectPhoto: "image/jpeg"
        case .invoice: "application/pdf"
        }
    }
}

nonisolated protocol RemoteAssetAnalyzing: Sendable {
    func analyze(
        kind: AssetExtractionKind,
        data: Data,
        locale: Locale
    ) async throws -> AssetAnalysisSuggestion
}

nonisolated final class RemoteAssetAnalysisClient: RemoteAssetAnalyzing, @unchecked Sendable {
    private static let productionBaseURL = URL(string: "https://kara.rahman-dev.ovh")!

    private static var configuredBaseURL: URL {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "KARAAPIBaseURL") as? String,
              let url = URL(string: value),
              url.scheme == "https" || url.host == "127.0.0.1"
        else { return productionBaseURL }
        return url
    }

    private let baseURL: URL
    private let transport: any APIDataTransport

    init() {
        let baseURL = Self.configuredBaseURL
        self.baseURL = baseURL
        transport = AttestedAPITransport(baseURL: baseURL)
    }

    init(baseURL: URL, transport: any APIDataTransport) {
        self.baseURL = baseURL
        self.transport = transport
    }

    func analyze(
        kind: AssetExtractionKind,
        data: Data,
        locale: Locale
    ) async throws -> AssetAnalysisSuggestion {
        try Task.checkCancellation()
        let endpoint = baseURL.appending(path: "v1/asset-extraction")
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw AssetAnalysisError.technicalFailure
        }
        components.queryItems = [
            URLQueryItem(name: "kind", value: kind.rawValue),
            URLQueryItem(name: "locale", value: Self.bcp47Identifier(for: locale)),
        ]
        guard let url = components.url else {
            throw AssetAnalysisError.technicalFailure
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.httpBody = data
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(kind.contentType, forHTTPHeaderField: "Content-Type")
        request.setValue(String(data.count), forHTTPHeaderField: "Content-Length")

        let (responseData, response) = try await transport.data(for: request)
        try Task.checkCancellation()
        guard response.statusCode == 200 else {
            throw Self.error(for: response.statusCode, data: responseData)
        }

        do {
            let envelope = try JSONDecoder().decode(AssetExtractionEnvelope.self, from: responseData)
            return try envelope.validatedSuggestion()
        } catch let error as AssetAnalysisError {
            throw error
        } catch {
            throw AssetAnalysisError.invalidResponse
        }
    }

    private static func bcp47Identifier(for locale: Locale) -> String {
        Locale(identifier: locale.identifier).identifier(.bcp47)
    }

    private static func error(for status: Int, data: Data) -> AssetAnalysisError {
        let code = try? JSONDecoder().decode(AssetExtractionErrorEnvelope.self, from: data).error.code
        return switch code {
        case "INVALID_ANALYSIS_INPUT", "UNSUPPORTED_MEDIA_TYPE": AssetAnalysisError.invalidInput
        case "ANALYSIS_PAYLOAD_TOO_LARGE": AssetAnalysisError.payloadTooLarge
        case "ANALYSIS_RATE_LIMITED": AssetAnalysisError.rateLimited
        case "ANALYSIS_DAILY_LIMIT_REACHED": AssetAnalysisError.dailyLimitReached
        case "ANALYSIS_QUARANTINED": AssetAnalysisError.quarantined
        case "ANALYSIS_REFUSED": AssetAnalysisError.refused
        case "INVALID_UPSTREAM_RESPONSE": AssetAnalysisError.invalidResponse
        case "ANALYSIS_TIMEOUT": AssetAnalysisError.timeout
        case "ANALYSIS_UNAVAILABLE": AssetAnalysisError.unavailable
        default:
            status == 413
                ? AssetAnalysisError.payloadTooLarge
                : AssetAnalysisError.technicalFailure
        }
    }
}

private nonisolated struct AssetExtractionErrorEnvelope: Decodable {
    struct APIError: Decodable { let code: String }
    let error: APIError
}
