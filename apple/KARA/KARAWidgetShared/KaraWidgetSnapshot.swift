import Foundation

nonisolated enum KaraWidgetMetal: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case gold = "XAU"
    case silver = "XAG"
    case platinum = "XPT"
    case palladium = "XPD"

    var id: Self { self }
}

nonisolated struct KaraWidgetQuote: Codable, Equatable, Identifiable, Sendable {
    let metal: KaraWidgetMetal
    let ouncePrice: Decimal
    let unitGrams: Decimal
    let sourceUpdatedAt: Date

    var id: KaraWidgetMetal { metal }
    var pricePerGram: Decimal { ouncePrice / unitGrams }

    init(
        metal: KaraWidgetMetal,
        ouncePrice: Decimal,
        unitGrams: Decimal,
        sourceUpdatedAt: Date
    ) {
        self.metal = metal
        self.ouncePrice = ouncePrice
        self.unitGrams = unitGrams
        self.sourceUpdatedAt = sourceUpdatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case metal
        case ouncePrice
        case unitGrams
        case sourceUpdatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        metal = try container.decode(KaraWidgetMetal.self, forKey: .metal)
        ouncePrice = try container.decodeKaraWidgetDecimal(forKey: .ouncePrice)
        unitGrams = try container.decodeKaraWidgetDecimal(forKey: .unitGrams)
        sourceUpdatedAt = try container.decode(Date.self, forKey: .sourceUpdatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(metal, forKey: .metal)
        try container.encodeKaraWidgetDecimal(ouncePrice, forKey: .ouncePrice)
        try container.encodeKaraWidgetDecimal(unitGrams, forKey: .unitGrams)
        try container.encode(sourceUpdatedAt, forKey: .sourceUpdatedAt)
    }
}

nonisolated struct KaraWidgetHistoryPoint: Codable, Equatable, Identifiable, Sendable {
    let date: Date
    let valueEUR: Decimal

    var id: Date { date }

    init(date: Date, valueEUR: Decimal) {
        self.date = date
        self.valueEUR = valueEUR
    }

    private enum CodingKeys: String, CodingKey {
        case date
        case valueEUR
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(Date.self, forKey: .date)
        valueEUR = try container.decodeKaraWidgetDecimal(forKey: .valueEUR)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encodeKaraWidgetDecimal(valueEUR, forKey: .valueEUR)
    }
}

nonisolated struct KaraWidgetPortfolio: Codable, Equatable, Sendable {
    let totalValueEUR: Decimal
    let totalGainEUR: Decimal?
    let gainPercentage: Decimal?
    let valuedRecordCount: Int
    let totalRecordCount: Int
    let objectCount: Int
    let history: [KaraWidgetHistoryPoint]

    init(
        totalValueEUR: Decimal,
        totalGainEUR: Decimal?,
        gainPercentage: Decimal?,
        valuedRecordCount: Int,
        totalRecordCount: Int,
        objectCount: Int,
        history: [KaraWidgetHistoryPoint]
    ) {
        self.totalValueEUR = totalValueEUR
        self.totalGainEUR = totalGainEUR
        self.gainPercentage = gainPercentage
        self.valuedRecordCount = valuedRecordCount
        self.totalRecordCount = totalRecordCount
        self.objectCount = objectCount
        self.history = history
    }

    private enum CodingKeys: String, CodingKey {
        case totalValueEUR
        case totalGainEUR
        case gainPercentage
        case valuedRecordCount
        case totalRecordCount
        case objectCount
        case history
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalValueEUR = try container.decodeKaraWidgetDecimal(forKey: .totalValueEUR)
        totalGainEUR = try container.decodeKaraWidgetDecimalIfPresent(forKey: .totalGainEUR)
        gainPercentage = try container.decodeKaraWidgetDecimalIfPresent(forKey: .gainPercentage)
        valuedRecordCount = try container.decode(Int.self, forKey: .valuedRecordCount)
        totalRecordCount = try container.decode(Int.self, forKey: .totalRecordCount)
        objectCount = try container.decode(Int.self, forKey: .objectCount)
        history = try container.decode([KaraWidgetHistoryPoint].self, forKey: .history)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeKaraWidgetDecimal(totalValueEUR, forKey: .totalValueEUR)
        try container.encodeKaraWidgetDecimalIfPresent(totalGainEUR, forKey: .totalGainEUR)
        try container.encodeKaraWidgetDecimalIfPresent(gainPercentage, forKey: .gainPercentage)
        try container.encode(valuedRecordCount, forKey: .valuedRecordCount)
        try container.encode(totalRecordCount, forKey: .totalRecordCount)
        try container.encode(objectCount, forKey: .objectCount)
        try container.encode(history, forKey: .history)
    }
}

nonisolated enum KaraWidgetDisclosure: String, Codable, Equatable, Sendable {
    case visible
    case hidden
    case unavailable
}

nonisolated struct KaraWidgetSnapshot: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let generatedAt: Date
    let quotes: [KaraWidgetQuote]
    let portfolio: KaraWidgetPortfolio?
    let disclosure: KaraWidgetDisclosure

    init(
        schemaVersion: Int = KaraWidgetSnapshot.currentSchemaVersion,
        generatedAt: Date,
        quotes: [KaraWidgetQuote],
        portfolio: KaraWidgetPortfolio?,
        disclosure: KaraWidgetDisclosure
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.quotes = quotes
        self.portfolio = portfolio
        self.disclosure = disclosure
    }

    func quote(for metal: KaraWidgetMetal) -> KaraWidgetQuote? {
        quotes.first { $0.metal == metal }
    }

    func hasSameContent(as other: Self) -> Bool {
        schemaVersion == other.schemaVersion
            && quotes.sortedByMetal == other.quotes.sortedByMetal
            && portfolio == other.portfolio
            && disclosure == other.disclosure
    }

    @discardableResult
    func validated() throws -> Self {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw KaraWidgetSnapshotValidationError.unsupportedSchemaVersion(schemaVersion)
        }
        guard generatedAt.timeIntervalSinceReferenceDate.isFinite else {
            throw KaraWidgetSnapshotValidationError.invalidGeneratedAt
        }

        var seenMetals: Set<KaraWidgetMetal> = []
        for quote in quotes {
            guard seenMetals.insert(quote.metal).inserted else {
                throw KaraWidgetSnapshotValidationError.duplicateQuote(quote.metal)
            }
            guard quote.ouncePrice.isFinite, quote.ouncePrice > 0 else {
                throw KaraWidgetSnapshotValidationError.invalidOuncePrice(quote.metal)
            }
            guard quote.unitGrams.isFinite, quote.unitGrams > 0 else {
                throw KaraWidgetSnapshotValidationError.invalidUnitGrams(quote.metal)
            }
            guard quote.sourceUpdatedAt.timeIntervalSinceReferenceDate.isFinite else {
                throw KaraWidgetSnapshotValidationError.invalidSourceUpdatedAt(quote.metal)
            }
        }

        switch (disclosure, portfolio) {
        case let (.visible, portfolio?):
            try validate(portfolio)
        case (.hidden, nil), (.unavailable, nil):
            break
        case (.visible, nil), (.hidden, _?), (.unavailable, _?):
            throw KaraWidgetSnapshotValidationError.inconsistentDisclosure(disclosure)
        }

        return self
    }

    private func validate(_ portfolio: KaraWidgetPortfolio) throws {
        guard portfolio.totalValueEUR.isFinite, portfolio.totalValueEUR >= 0,
              portfolio.totalGainEUR?.isFinite ?? true,
              portfolio.gainPercentage?.isFinite ?? true
        else {
            throw KaraWidgetSnapshotValidationError.invalidPortfolioNumber
        }
        guard portfolio.totalRecordCount >= 0,
              portfolio.valuedRecordCount >= 0,
              portfolio.valuedRecordCount <= portfolio.totalRecordCount,
              portfolio.objectCount >= 0
        else {
            throw KaraWidgetSnapshotValidationError.invalidPortfolioCoverage
        }

        var seenDates: Set<Date> = []
        var previousDate: Date?
        for point in portfolio.history {
            guard point.date.timeIntervalSinceReferenceDate.isFinite,
                  point.valueEUR.isFinite,
                  point.valueEUR >= 0
            else {
                throw KaraWidgetSnapshotValidationError.invalidHistoryPoint
            }
            guard seenDates.insert(point.date).inserted else {
                throw KaraWidgetSnapshotValidationError.duplicateHistoryDate(point.date)
            }
            if let previousDate, point.date < previousDate {
                throw KaraWidgetSnapshotValidationError.nonChronologicalHistory
            }
            previousDate = point.date
        }
    }
}

nonisolated enum KaraWidgetSnapshotValidationError: Error, Equatable, Sendable {
    case unsupportedSchemaVersion(Int)
    case invalidGeneratedAt
    case duplicateQuote(KaraWidgetMetal)
    case invalidOuncePrice(KaraWidgetMetal)
    case invalidUnitGrams(KaraWidgetMetal)
    case invalidSourceUpdatedAt(KaraWidgetMetal)
    case invalidPortfolioNumber
    case invalidPortfolioCoverage
    case invalidHistoryPoint
    case duplicateHistoryDate(Date)
    case nonChronologicalHistory
    case inconsistentDisclosure(KaraWidgetDisclosure)
}

private nonisolated extension Array where Element == KaraWidgetQuote {
    var sortedByMetal: Self {
        sorted { $0.metal.rawValue < $1.metal.rawValue }
    }
}

private nonisolated extension KeyedDecodingContainer {
    func decodeKaraWidgetDecimal(forKey key: Key) throws -> Decimal {
        if let value = try? decode(String.self, forKey: key),
           let decimal = Decimal(
               string: value,
               locale: Locale(identifier: "en_US_POSIX")
           ) {
            return decimal
        }
        if let decimal = try? decode(Decimal.self, forKey: key) {
            return decimal
        }
        throw DecodingError.dataCorruptedError(
            forKey: key,
            in: self,
            debugDescription: "Expected a decimal string or number."
        )
    }

    func decodeKaraWidgetDecimalIfPresent(forKey key: Key) throws -> Decimal? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        return try decodeKaraWidgetDecimal(forKey: key)
    }
}

private nonisolated extension KeyedEncodingContainer {
    mutating func encodeKaraWidgetDecimal(_ value: Decimal, forKey key: Key) throws {
        try encode(NSDecimalNumber(decimal: value).stringValue, forKey: key)
    }

    mutating func encodeKaraWidgetDecimalIfPresent(
        _ value: Decimal?,
        forKey key: Key
    ) throws {
        guard let value else {
            try encodeNil(forKey: key)
            return
        }
        try encodeKaraWidgetDecimal(value, forKey: key)
    }
}
