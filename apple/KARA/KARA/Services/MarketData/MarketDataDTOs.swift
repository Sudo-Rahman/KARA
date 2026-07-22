import Foundation

nonisolated enum MarketMetal: String, CaseIterable, Codable, Hashable, Sendable {
    case gold = "XAU"
    case silver = "XAG"
    case platinum = "XPT"
    case palladium = "XPD"
}

nonisolated enum MarketCurrency: String, CaseIterable, Codable, Sendable {
    case eur = "EUR"
    case usd = "USD"
    case chf = "CHF"
    case gbp = "GBP"
}

nonisolated struct SpotPair: Hashable, Codable, Sendable {
    let metal: MarketMetal
    let currency: MarketCurrency

    init(metal: MarketMetal, currency: MarketCurrency) {
        self.metal = metal
        self.currency = currency
    }
}

nonisolated enum MarketUnitCode: String, Codable, Sendable {
    case troyOunce = "troy_ounce"
}

nonisolated struct MarketUnit: Codable, Equatable, Sendable {
    let code: MarketUnitCode
    let grams: Decimal

    init(code: MarketUnitCode, grams: Decimal) {
        self.code = code
        self.grams = grams
    }

    private enum CodingKeys: String, CodingKey {
        case code
        case grams
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(MarketUnitCode.self, forKey: .code)
        grams = try container.decodeStringDecimal(forKey: .grams)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(code, forKey: .code)
        try container.encodeDecimalString(grams, forKey: .grams)
    }
}

nonisolated struct SpotQuote: Codable, Equatable, Sendable, Identifiable {
    let schemaVersion: Int
    let metal: MarketMetal
    let currency: MarketCurrency
    let price: Decimal
    let unit: MarketUnit
    let sourceUpdatedAt: Date

    var id: SpotPair { SpotPair(metal: metal, currency: currency) }
    var pricePerGram: Decimal { price / unit.grams }

    init(
        schemaVersion: Int = 1,
        metal: MarketMetal,
        currency: MarketCurrency,
        price: Decimal,
        unit: MarketUnit,
        sourceUpdatedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.metal = metal
        self.currency = currency
        self.price = price
        self.unit = unit
        self.sourceUpdatedAt = sourceUpdatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case metal
        case currency
        case price
        case unit
        case sourceUpdatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        metal = try container.decode(MarketMetal.self, forKey: .metal)
        currency = try container.decode(MarketCurrency.self, forKey: .currency)
        price = try container.decodeStringDecimal(forKey: .price)
        unit = try container.decode(MarketUnit.self, forKey: .unit)
        sourceUpdatedAt = try container.decode(Date.self, forKey: .sourceUpdatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(metal, forKey: .metal)
        try container.encode(currency, forKey: .currency)
        try container.encodeDecimalString(price, forKey: .price)
        try container.encode(unit, forKey: .unit)
        try container.encode(sourceUpdatedAt, forKey: .sourceUpdatedAt)
    }

    func validated(for expectedPair: SpotPair? = nil) throws -> Self {
        guard schemaVersion == 1 else {
            throw MarketPayloadError.unsupportedSchemaVersion(schemaVersion)
        }
        guard price >= 0, unit.grams > 0 else {
            throw MarketPayloadError.invalidValue
        }
        if let expectedPair, id != expectedPair {
            throw MarketPayloadError.unexpectedSpotPair(expected: expectedPair, received: id)
        }
        return self
    }
}

nonisolated struct MonthlyMethodology: Codable, Equatable, Sendable {
    let nominal: Bool
    let currencyConversion: String
    let roundingDecimals: Int
    let roundingMode: String
}

nonisolated struct MonthlySource: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let role: String
    let title: String
    let url: URL
    let attribution: String
    let termsUrl: URL
}

nonisolated struct MonthlyObservation: Codable, Equatable, Sendable, Identifiable {
    let month: String
    let prices: [String: Decimal]

    var id: String { month }

    init(month: String, prices: [String: Decimal]) {
        self.month = month
        self.prices = prices
    }

    private enum CodingKeys: String, CodingKey {
        case month
        case prices
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        month = try container.decode(String.self, forKey: .month)
        let priceContainer = try container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .prices)
        prices = try Dictionary(uniqueKeysWithValues: priceContainer.allKeys.map { key in
            (key.stringValue, try priceContainer.decodeStringDecimal(forKey: key))
        })
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(month, forKey: .month)
        var priceContainer = container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .prices)
        for (currency, price) in prices {
            try priceContainer.encodeDecimalString(price, forKey: DynamicCodingKey(currency))
        }
    }

    func price(in currency: MarketCurrency) -> Decimal? {
        prices[currency.rawValue]
    }
}

nonisolated struct MonthlySeries: Codable, Equatable, Sendable, Identifiable {
    let metal: MarketMetal
    let observations: [MonthlyObservation]

    var id: MarketMetal { metal }
}

nonisolated struct MonthlyDataset: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let datasetId: String
    let frequency: String
    let priceKind: String
    let unit: MarketUnit
    let methodology: MonthlyMethodology
    let sources: [MonthlySource]
    let series: [MonthlySeries]

    init(
        schemaVersion: Int = 1,
        datasetId: String = "precious-metals-monthly",
        frequency: String = "monthly",
        priceKind: String = "monthly_average",
        unit: MarketUnit,
        methodology: MonthlyMethodology = MonthlyMethodology(
            nominal: true,
            currencyConversion: "ratio_of_monthly_average_rates",
            roundingDecimals: 6,
            roundingMode: "half_even"
        ),
        sources: [MonthlySource] = [],
        series: [MonthlySeries]
    ) {
        self.schemaVersion = schemaVersion
        self.datasetId = datasetId
        self.frequency = frequency
        self.priceKind = priceKind
        self.unit = unit
        self.methodology = methodology
        self.sources = sources
        self.series = series
    }

    func observations(for metal: MarketMetal) -> [MonthlyObservation] {
        series.first(where: { $0.metal == metal })?.observations ?? []
    }

    func price(for metal: MarketMetal, currency: MarketCurrency, month: String) -> Decimal? {
        observations(for: metal)
            .first(where: { $0.month == month })?
            .price(in: currency)
    }

    func validated() throws -> Self {
        guard schemaVersion == 1 else {
            throw MarketPayloadError.unsupportedSchemaVersion(schemaVersion)
        }
        guard datasetId == "precious-metals-monthly",
              frequency == "monthly",
              priceKind == "monthly_average",
              unit.grams > 0
        else {
            throw MarketPayloadError.invalidValue
        }
        return self
    }
}

nonisolated struct MarketManifest: Codable, Equatable, Sendable {
    struct Coverage: Codable, Equatable, Sendable {
        let from: String
        let through: String
    }

    struct CurrencyCoverage: Codable, Equatable, Sendable {
        let from: String
        let through: String
    }

    struct File: Codable, Equatable, Sendable {
        let url: String
        let sha256: String
        let bytes: Int
    }

    let schemaVersion: Int
    let datasetId: String
    let dataVersion: String
    let publishedAt: Date
    let metals: [MarketMetal]
    let coverage: Coverage
    let currencies: [String: CurrencyCoverage]
    let file: File

    func validated() throws -> Self {
        guard schemaVersion == 1 else {
            throw MarketPayloadError.unsupportedSchemaVersion(schemaVersion)
        }
        guard datasetId == "precious-metals-monthly", !dataVersion.isEmpty else {
            throw MarketPayloadError.invalidValue
        }
        return self
    }
}

nonisolated enum MarketPayloadError: Error, Equatable, Sendable {
    case invalidDecimal(String)
    case unsupportedSchemaVersion(Int)
    case unexpectedSpotPair(expected: SpotPair, received: SpotPair)
    case invalidValue
}

nonisolated enum MarketJSON {
    static var decoder: JSONDecoder { makeDecoder() }
    static var encoder: JSONEncoder { makeEncoder() }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) {
                return date
            }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "Invalid ISO-8601 date: \(value)"
            )
        }
        return decoder
    }

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

private nonisolated struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int? = nil

    init(_ stringValue: String) {
        self.stringValue = stringValue
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue: Int) {
        return nil
    }
}

private nonisolated extension KeyedDecodingContainer {
    func decodeStringDecimal(forKey key: Key) throws -> Decimal {
        if let string = try? decode(String.self, forKey: key),
           let decimal = Decimal(string: string, locale: Locale(identifier: "en_US_POSIX")) {
            return decimal
        }
        if let decimal = try? decode(Decimal.self, forKey: key) {
            return decimal
        }
        let value = (try? decode(String.self, forKey: key)) ?? "<non-decimal>"
        throw MarketPayloadError.invalidDecimal(value)
    }
}

private nonisolated extension KeyedEncodingContainer {
    mutating func encodeDecimalString(_ value: Decimal, forKey key: Key) throws {
        try encode(NSDecimalNumber(decimal: value).stringValue, forKey: key)
    }
}
