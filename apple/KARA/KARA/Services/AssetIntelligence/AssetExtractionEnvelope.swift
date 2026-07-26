import Foundation

nonisolated struct AssetExtractionEnvelope: Decodable {
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
        guard schemaVersion == 2 else { throw AssetAnalysisError.invalidResponse }
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
        let name: Candidate<String>?
        let category: Candidate<String>?
        let presetID: Candidate<String>?
        let quantity: Candidate<Int>?
        let purchaseDate: Candidate<String>?
        let metal: Candidate<String>?
        let weightGrams: Candidate<Double>?
        let metalKarat: Candidate<Int>?
        let finenessPermille: Candidate<Double>?
        let gemstoneCaratWeight: Candidate<Double>?
        let gemstoneClarity: Candidate<String>?
        let pricePaid: Candidate<PriceValue>?
        let sellerName: Candidate<String>?
        let storageLocationName: Candidate<String>?
        let invoiceNumber: Candidate<String>?
        let serialNumber: Candidate<String>?
        let acquisitionMethod: Candidate<String>?

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
            case pricePaid
            case sellerName
            case storageLocationName
            case invoiceNumber
            case serialNumber
            case acquisitionMethod
        }

        init(from decoder: Decoder) throws {
            try AssetExtractionEnvelope.requireExactKeys(
                decoder,
                expected: CodingKeys.allCases.map(\.stringValue)
            )
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decodeIfPresent(Candidate<String>.self, forKey: .name)
            category = try container.decodeIfPresent(Candidate<String>.self, forKey: .category)
            presetID = try container.decodeIfPresent(Candidate<String>.self, forKey: .presetID)
            quantity = try container.decodeIfPresent(Candidate<Int>.self, forKey: .quantity)
            purchaseDate = try container.decodeIfPresent(Candidate<String>.self, forKey: .purchaseDate)
            metal = try container.decodeIfPresent(Candidate<String>.self, forKey: .metal)
            weightGrams = try container.decodeIfPresent(Candidate<Double>.self, forKey: .weightGrams)
            metalKarat = try container.decodeIfPresent(Candidate<Int>.self, forKey: .metalKarat)
            finenessPermille = try container.decodeIfPresent(Candidate<Double>.self, forKey: .finenessPermille)
            gemstoneCaratWeight = try container.decodeIfPresent(
                Candidate<Double>.self,
                forKey: .gemstoneCaratWeight
            )
            gemstoneClarity = try container.decodeIfPresent(Candidate<String>.self, forKey: .gemstoneClarity)
            pricePaid = try container.decodeIfPresent(Candidate<PriceValue>.self, forKey: .pricePaid)
            sellerName = try container.decodeIfPresent(Candidate<String>.self, forKey: .sellerName)
            storageLocationName = try container.decodeIfPresent(
                Candidate<String>.self,
                forKey: .storageLocationName
            )
            invoiceNumber = try container.decodeIfPresent(Candidate<String>.self, forKey: .invoiceNumber)
            serialNumber = try container.decodeIfPresent(Candidate<String>.self, forKey: .serialNumber)
            acquisitionMethod = try container.decodeIfPresent(
                Candidate<String>.self,
                forKey: .acquisitionMethod
            )
        }

        func validated() throws -> AssetAnalysisSuggestion {
            let analyzedCategory = try mapCandidate(category) { value in
                guard let category = AssetCategory(analysisIdentifier: value) else {
                    throw AssetAnalysisError.invalidResponse
                }
                return category
            }
            let analyzedPreset = try mapCandidate(presetID) { value in
                guard let preset = AssetCatalog.preset(id: value) else {
                    throw AssetAnalysisError.invalidResponse
                }
                return preset
            }
            let analyzedMetal = try mapCandidate(metal) { value in
                guard let metal = PreciousMetal(rawValue: value) else {
                    throw AssetAnalysisError.invalidResponse
                }
                return metal
            }

            try validatePresetConsistency(
                preset: analyzedPreset?.value,
                category: analyzedCategory?.value,
                metal: analyzedMetal?.value
            )

            var suggestion = AssetAnalysisSuggestion()
            suggestion.name = try mapCandidate(name, transform: normalizedDisplayText)
            suggestion.category = analyzedCategory
            suggestion.presetID = analyzedPreset.map {
                AssetAnalysisCandidate(value: $0.value.id, assessment: $0.assessment)
            }
            suggestion.quantity = try mapCandidate(quantity) { value in
                guard value > 0 else { throw AssetAnalysisError.invalidResponse }
                return value
            }
            suggestion.purchaseDate = try mapCandidate(purchaseDate) { try parseDate($0) }
            suggestion.metal = analyzedMetal
            suggestion.weightGrams = try mapCandidate(weightGrams, transform: positiveFinite)
            suggestion.metalKarat = try mapCandidate(metalKarat) { value in
                guard (1 ... 24).contains(value) else {
                    throw AssetAnalysisError.invalidResponse
                }
                return value
            }
            suggestion.finenessPermille = try mapCandidate(finenessPermille) { value in
                guard value.isFinite, value > 0, value <= 1_000 else {
                    throw AssetAnalysisError.invalidResponse
                }
                return value
            }
            suggestion.gemstoneCaratWeight = try mapCandidate(
                gemstoneCaratWeight,
                transform: positiveFinite
            )
            suggestion.gemstoneClarity = try mapCandidate(
                gemstoneClarity,
                transform: normalizedDisplayText
            )
            suggestion.pricePaid = try mapCandidate(pricePaid) { value in
                guard value.minorUnits >= 0,
                      let currency = SupportedAssetCurrency(rawValue: value.currencyCode)
                else {
                    throw AssetAnalysisError.invalidResponse
                }
                    return AssetAnalysisPrice(
                        minorUnits: value.minorUnits,
                        currency: currency
                )
            }
            suggestion.sellerName = try mapCandidate(sellerName, transform: normalizedDisplayText)
            suggestion.storageLocationName = try mapCandidate(
                storageLocationName,
                transform: normalizedDisplayText
            )
            suggestion.invoiceNumber = try mapCandidate(invoiceNumber, transform: exactIdentifier)
            suggestion.serialNumber = try mapCandidate(serialNumber, transform: exactIdentifier)
            suggestion.acquisitionMethod = try mapCandidate(acquisitionMethod) { value in
                guard let method = AssetAcquisitionMethod(rawValue: value) else {
                    throw AssetAnalysisError.invalidResponse
                }
                return method
            }
            return suggestion
        }

        private func mapCandidate<Input: Decodable & Equatable & Sendable, Output: Equatable & Sendable>(
            _ candidate: Candidate<Input>?,
            transform: (Input) throws -> Output?
        ) throws -> AssetAnalysisCandidate<Output>? {
            guard let candidate,
                  let value = try transform(candidate.value)
            else {
                return nil
            }
            return AssetAnalysisCandidate(
                value: value,
                assessment: try candidate.assessment()
            )
        }

        private func validatePresetConsistency(
            preset: AssetPreset?,
            category: AssetCategory?,
            metal: PreciousMetal?
        ) throws {
            guard let preset else { return }
            guard AssetPresetCompatibility.matches(
                preset,
                category: category,
                metal: metal,
                weightGrams: weightGrams?.value,
                finenessPermille: finenessPermille?.value,
                metalKarat: metalKarat?.value
            ) else {
                throw AssetAnalysisError.invalidResponse
            }
        }

        private func positiveFinite(_ value: Double) throws -> Double {
            guard value.isFinite, value > 0 else {
                throw AssetAnalysisError.invalidResponse
            }
            return value
        }

        private func normalizedDisplayText(_ value: String) -> String? {
            let normalized = AssetSuggestionNormalizer.displayName(value)
            guard !normalized.isEmpty else { return nil }
            return normalized
        }

        private func exactIdentifier(_ value: String) -> String? {
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

    struct Candidate<Value: Decodable & Equatable & Sendable>: Decodable {
        let value: Value
        let confidencePercent: Int
        let evidenceKind: String

        private enum CodingKeys: String, CodingKey, CaseIterable {
            case value
            case confidencePercent
            case evidenceKind
        }

        init(from decoder: Decoder) throws {
            try AssetExtractionEnvelope.requireExactKeys(
                decoder,
                expected: CodingKeys.allCases.map(\.stringValue)
            )
            let container = try decoder.container(keyedBy: CodingKeys.self)
            value = try container.decode(Value.self, forKey: .value)
            confidencePercent = try container.decode(Int.self, forKey: .confidencePercent)
            evidenceKind = try container.decode(String.self, forKey: .evidenceKind)
        }

        func assessment() throws -> AssetFieldAssessment {
            guard (1 ... 100).contains(confidencePercent),
                  let evidence = AssetAnalysisEvidenceKind(rawValue: evidenceKind),
                  evidence != .catalogDerived
            else { throw AssetAnalysisError.invalidResponse }
            return AssetFieldAssessment(
                confidencePercent: confidencePercent,
                evidenceKind: evidence
            )
        }
    }

    struct PriceValue: Decodable, Equatable, Sendable {
        let minorUnits: Int64
        let currencyCode: String

        private enum CodingKeys: String, CodingKey, CaseIterable {
            case minorUnits
            case currencyCode
        }

        init(from decoder: Decoder) throws {
            try AssetExtractionEnvelope.requireExactKeys(
                decoder,
                expected: CodingKeys.allCases.map(\.stringValue)
            )
            let container = try decoder.container(keyedBy: CodingKeys.self)
            minorUnits = try container.decode(Int64.self, forKey: .minorUnits)
            currencyCode = try container.decode(String.self, forKey: .currencyCode)
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
