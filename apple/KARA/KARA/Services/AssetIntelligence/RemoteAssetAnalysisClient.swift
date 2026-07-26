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

private nonisolated struct AssetExtractionEnvelope: Decodable {
    let schemaVersion: Int
    let suggestion: Suggestion

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case schemaVersion
        case suggestion
    }

    init(from decoder: Decoder) throws {
        try Self.requireExactKeys(
            decoder,
            expected: CodingKeys.allCases.map(\.stringValue)
        )
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        suggestion = try container.decode(Suggestion.self, forKey: .suggestion)
    }

    func validatedSuggestion() throws -> AssetAnalysisSuggestion {
        guard schemaVersion == 1 else { throw AssetAnalysisError.invalidResponse }
        return try suggestion.validated()
    }

    fileprivate static func requireExactKeys(
        _ decoder: Decoder,
        expected: [String]
    ) throws {
        let container = try decoder.container(keyedBy: StrictCodingKey.self)
        guard Set(container.allKeys.map(\.stringValue)) == Set(expected) else {
            throw AssetAnalysisError.invalidResponse
        }
    }

    struct Suggestion: Decodable {
        let name: String?
        let category: String?
        let presetID: String?
        let quantity: Int?
        let purchaseDate: String?
        let metal: String?
        let weightGrams: Double?
        let metalKarat: Int?
        let finenessPermille: Double?
        let gemstoneCaratWeight: Double?
        let gemstoneClarity: String?
        let pricePaidMinorUnits: Int64?
        let currencyCode: String?
        let sellerName: String?
        let storageLocationName: String?
        let invoiceNumber: String?
        let serialNumber: String?

        private enum CodingKeys: String, CodingKey, CaseIterable {
            case name
            case category
            case presetID = "presetId"
            case quantity
            case purchaseDate
            case metal
            case weightGrams
            case metalKarat
            case finenessPermille
            case gemstoneCaratWeight
            case gemstoneClarity
            case pricePaidMinorUnits
            case currencyCode
            case sellerName
            case storageLocationName
            case invoiceNumber
            case serialNumber
        }

        init(from decoder: Decoder) throws {
            try AssetExtractionEnvelope.requireExactKeys(
                decoder,
                expected: CodingKeys.allCases.map(\.stringValue)
            )
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decodeIfPresent(String.self, forKey: .name)
            category = try container.decodeIfPresent(String.self, forKey: .category)
            presetID = try container.decodeIfPresent(String.self, forKey: .presetID)
            quantity = try container.decodeIfPresent(Int.self, forKey: .quantity)
            purchaseDate = try container.decodeIfPresent(String.self, forKey: .purchaseDate)
            metal = try container.decodeIfPresent(String.self, forKey: .metal)
            weightGrams = try container.decodeIfPresent(Double.self, forKey: .weightGrams)
            metalKarat = try container.decodeIfPresent(Int.self, forKey: .metalKarat)
            finenessPermille = try container.decodeIfPresent(Double.self, forKey: .finenessPermille)
            gemstoneCaratWeight = try container.decodeIfPresent(Double.self, forKey: .gemstoneCaratWeight)
            gemstoneClarity = try container.decodeIfPresent(String.self, forKey: .gemstoneClarity)
            pricePaidMinorUnits = try container.decodeIfPresent(Int64.self, forKey: .pricePaidMinorUnits)
            currencyCode = try container.decodeIfPresent(String.self, forKey: .currencyCode)
            sellerName = try container.decodeIfPresent(String.self, forKey: .sellerName)
            storageLocationName = try container.decodeIfPresent(String.self, forKey: .storageLocationName)
            invoiceNumber = try container.decodeIfPresent(String.self, forKey: .invoiceNumber)
            serialNumber = try container.decodeIfPresent(String.self, forKey: .serialNumber)
        }

        func validated() throws -> AssetAnalysisSuggestion {
            let validatedCategory = try validateOptional(category) {
                AssetCategory(analysisIdentifier: $0)
            }
            let validatedPreset = try validateOptional(presetID) { value in
                AssetCatalog.preset(id: value)
            }
            let validatedMetal = try validateOptional(metal) { PreciousMetal(rawValue: $0) }
            let validatedCurrency = try validateOptional(currencyCode) {
                SupportedAssetCurrency(rawValue: $0)?.rawValue
            }

            if let quantity, quantity < 1 { throw AssetAnalysisError.invalidResponse }
            if let metalKarat, !(1...24).contains(metalKarat) {
                throw AssetAnalysisError.invalidResponse
            }
            try validatePositiveFinite(weightGrams)
            try validatePositiveFinite(gemstoneCaratWeight)
            if let finenessPermille,
               !finenessPermille.isFinite || finenessPermille <= 0 || finenessPermille > 1_000 {
                throw AssetAnalysisError.invalidResponse
            }
            if let pricePaidMinorUnits, pricePaidMinorUnits < 0 {
                throw AssetAnalysisError.invalidResponse
            }
            try validatePresetConsistency(
                preset: validatedPreset,
                category: validatedCategory,
                metal: validatedMetal
            )

            return AssetAnalysisSuggestion(
                name: normalizedDisplayText(name),
                category: validatedCategory,
                presetID: validatedPreset?.id,
                quantity: quantity,
                purchaseDate: try purchaseDate.map(parseDate),
                metal: validatedMetal,
                weightGrams: weightGrams,
                metalKarat: metalKarat,
                finenessPermille: finenessPermille,
                gemstoneCaratWeight: gemstoneCaratWeight,
                gemstoneClarity: normalizedDisplayText(gemstoneClarity),
                pricePaidMinorUnits: pricePaidMinorUnits,
                currencyCode: validatedCurrency,
                sellerName: normalizedDisplayText(sellerName),
                storageLocationName: normalizedDisplayText(storageLocationName),
                invoiceNumber: normalizedDisplayText(invoiceNumber),
                serialNumber: exactIdentifier(serialNumber)
            )
        }

        private func validatePresetConsistency(
            preset: AssetPreset?,
            category: AssetCategory?,
            metal: PreciousMetal?
        ) throws {
            guard let preset else { return }
            if let category, category != preset.category {
                throw AssetAnalysisError.invalidResponse
            }
            if let expectedMetal = preset.metal,
               let metal,
               metal != expectedMetal {
                throw AssetAnalysisError.invalidResponse
            }
            if !matchesPresetNumber(weightGrams, expected: preset.weightGrams)
                || !matchesPresetNumber(
                    finenessPermille,
                    expected: preset.finenessPermille,
                    relativeTolerance: 0.002,
                    absoluteTolerance: 1
                )
            {
                throw AssetAnalysisError.invalidResponse
            }
            if let expectedKarat = preset.metalKarat,
               let metalKarat,
               metalKarat != expectedKarat {
                throw AssetAnalysisError.invalidResponse
            }
        }

        private func matchesPresetNumber(
            _ value: Double?,
            expected: Double?,
            relativeTolerance: Double = 0.01,
            absoluteTolerance: Double = 0.01
        ) -> Bool {
            guard let value, let expected else { return true }
            let tolerance = max(absoluteTolerance, abs(expected) * relativeTolerance)
            return abs(value - expected) <= tolerance
        }

        private func validateOptional<Value, Output>(
            _ value: Value?,
            transform: (Value) -> Output?
        ) throws -> Output? {
            guard let value else { return nil }
            guard let output = transform(value) else {
                throw AssetAnalysisError.invalidResponse
            }
            return output
        }

        private func validatePositiveFinite(_ value: Double?) throws {
            guard let value else { return }
            guard value.isFinite, value > 0 else {
                throw AssetAnalysisError.invalidResponse
            }
        }

        private func normalizedDisplayText(_ value: String?) -> String? {
            guard let value else { return nil }
            let normalized = AssetSuggestionNormalizer.displayName(value)
            guard !normalized.isEmpty else { return nil }
            return normalized
        }

        private func exactIdentifier(_ value: String?) -> String? {
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        private func parseDate(_ value: String) throws -> Date {
            let parts = value.split(separator: "-", omittingEmptySubsequences: false)
            guard parts.count == 3,
                  parts[0].count == 4,
                  parts[1].count == 2,
                  parts[2].count == 2,
                  let year = Int(parts[0]),
                  let month = Int(parts[1]),
                  let day = Int(parts[2])
            else { throw AssetAnalysisError.invalidResponse }

            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let components = DateComponents(
                calendar: calendar,
                timeZone: calendar.timeZone,
                year: year,
                month: month,
                day: day
            )
            guard let date = calendar.date(from: components) else {
                throw AssetAnalysisError.invalidResponse
            }
            let roundTrip = calendar.dateComponents([.year, .month, .day], from: date)
            guard roundTrip.year == year,
                  roundTrip.month == month,
                  roundTrip.day == day
            else { throw AssetAnalysisError.invalidResponse }
            return date
        }
    }
}

private nonisolated struct StrictCodingKey: CodingKey, Hashable {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}
