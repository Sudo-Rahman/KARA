import Foundation

nonisolated struct AssetAnalysisSuggestion: Equatable, Sendable {
    var name: String?
    var category: AssetCategory?
    var presetID: String?
    var quantity: Int?
    var purchaseDate: Date?
    var metal: PreciousMetal?
    var weightGrams: Double?
    var metalKarat: Int?
    var finenessPermille: Double?
    var gemstoneCaratWeight: Double?
    var gemstoneClarity: String?
    var pricePaidMinorUnits: Int64?
    var currencyCode: String?
    var sellerName: String?
    var storageLocationName: String?
    var invoiceNumber: String?

    init(
        name: String? = nil,
        category: AssetCategory? = nil,
        presetID: String? = nil,
        quantity: Int? = nil,
        purchaseDate: Date? = nil,
        metal: PreciousMetal? = nil,
        weightGrams: Double? = nil,
        metalKarat: Int? = nil,
        finenessPermille: Double? = nil,
        gemstoneCaratWeight: Double? = nil,
        gemstoneClarity: String? = nil,
        pricePaidMinorUnits: Int64? = nil,
        currencyCode: String? = nil,
        sellerName: String? = nil,
        storageLocationName: String? = nil,
        invoiceNumber: String? = nil
    ) {
        self.name = name
        self.category = category
        self.presetID = presetID
        self.quantity = quantity
        self.purchaseDate = purchaseDate
        self.metal = metal
        self.weightGrams = weightGrams
        self.metalKarat = metalKarat
        self.finenessPermille = finenessPermille
        self.gemstoneCaratWeight = gemstoneCaratWeight
        self.gemstoneClarity = gemstoneClarity
        self.pricePaidMinorUnits = pricePaidMinorUnits
        self.currencyCode = currencyCode
        self.sellerName = sellerName
        self.storageLocationName = storageLocationName
        self.invoiceNumber = invoiceNumber
    }
}

nonisolated struct AssetAttachmentPayload: Equatable, Sendable {
    let kind: AssetAttachmentKind
    let filename: String
    let mimeType: String
    let pageCount: Int?
    let data: Data

    init(
        kind: AssetAttachmentKind,
        filename: String,
        mimeType: String,
        pageCount: Int? = nil,
        data: Data
    ) {
        self.kind = kind
        self.filename = filename
        self.mimeType = mimeType
        self.pageCount = pageCount
        self.data = data
    }
}

@MainActor
protocol AssetSaving {
    @discardableResult
    func save(draft: AssetDraft, attachments: [AssetAttachmentPayload]) throws -> Asset
}

nonisolated enum AssetDraftValidationError: Error, Equatable, Sendable {
    case missingName
    case missingCategory
    case invalidQuantity
    case invalidWeight
    case invalidMetalKarat
    case invalidFineness
    case invalidGemstoneCaratWeight
    case invalidPrice
    case invalidCurrencyCode
}

nonisolated struct AssetDraft: Equatable, Sendable {
    enum Field: String, CaseIterable, Hashable, Sendable {
        case name
        case category
        case presetID
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
    }

    var name: String
    var category: AssetCategory?
    var presetID: String?
    var quantity: Int
    var purchaseDate: Date?
    var metal: PreciousMetal?
    var weightGrams: Double?
    var metalKarat: Int?
    var finenessPermille: Double?
    var gemstoneCaratWeight: Double?
    var gemstoneClarity: String
    var pricePaidMinorUnits: Int64?
    var currencyCode: String
    var sellerName: String
    var storageLocationName: String
    var invoiceNumber: String
    private(set) var manuallyEditedFields: Set<Field>

    init(
        name: String = "",
        category: AssetCategory? = nil,
        presetID: String? = nil,
        quantity: Int = 1,
        purchaseDate: Date? = nil,
        metal: PreciousMetal? = nil,
        weightGrams: Double? = nil,
        metalKarat: Int? = nil,
        finenessPermille: Double? = nil,
        gemstoneCaratWeight: Double? = nil,
        gemstoneClarity: String = "",
        pricePaidMinorUnits: Int64? = nil,
        currencyCode: String = SupportedAssetCurrency.defaultCurrency.rawValue,
        sellerName: String = "",
        storageLocationName: String = "",
        invoiceNumber: String = "",
        manuallyEditedFields: Set<Field> = []
    ) {
        self.name = name
        self.category = category
        self.presetID = presetID
        self.quantity = quantity
        self.purchaseDate = purchaseDate
        self.metal = metal
        self.weightGrams = weightGrams
        self.metalKarat = metalKarat
        self.finenessPermille = finenessPermille
        self.gemstoneCaratWeight = gemstoneCaratWeight
        self.gemstoneClarity = gemstoneClarity
        self.pricePaidMinorUnits = pricePaidMinorUnits
        self.currencyCode = currencyCode
        self.sellerName = sellerName
        self.storageLocationName = storageLocationName
        self.invoiceNumber = invoiceNumber
        self.manuallyEditedFields = manuallyEditedFields
    }

    var validationErrors: [AssetDraftValidationError] {
        var errors: [AssetDraftValidationError] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.missingName)
        }
        if category == nil {
            errors.append(.missingCategory)
        }
        if quantity < 1 {
            errors.append(.invalidQuantity)
        }
        if let weightGrams, !weightGrams.isFinite || weightGrams <= 0 {
            errors.append(.invalidWeight)
        }
        if let metalKarat, !(1...24).contains(metalKarat) {
            errors.append(.invalidMetalKarat)
        }
        if let finenessPermille, !finenessPermille.isFinite || !(0...1_000).contains(finenessPermille) || finenessPermille == 0 {
            errors.append(.invalidFineness)
        }
        if let gemstoneCaratWeight, !gemstoneCaratWeight.isFinite || gemstoneCaratWeight <= 0 {
            errors.append(.invalidGemstoneCaratWeight)
        }
        if let pricePaidMinorUnits, pricePaidMinorUnits < 0 {
            errors.append(.invalidPrice)
        }
        if !SupportedAssetCurrency.isSupported(code: currencyCode) {
            errors.append(.invalidCurrencyCode)
        }
        return errors
    }

    var isValid: Bool { validationErrors.isEmpty }

    mutating func markAsManuallyEdited(_ field: Field) {
        manuallyEditedFields.insert(field)
    }

    mutating func apply(preset: AssetPreset) {
        presetID = preset.id
        category = preset.category
        name = preset.name
        metal = preset.metal
        weightGrams = preset.weightGrams
        metalKarat = preset.metalKarat
        finenessPermille = preset.finenessPermille
    }

    @discardableResult
    mutating func merge(
        suggestion: AssetAnalysisSuggestion,
        excluding excludedFields: Set<Field> = []
    ) -> Set<Field> {
        var appliedFields: Set<Field> = []

        if mergeString(\.name, field: .name, suggestion.name, excluding: excludedFields) {
            appliedFields.insert(.name)
        }
        if mergeOptional(\.category, field: .category, suggestion.category, excluding: excludedFields) {
            appliedFields.insert(.category)
        }
        if mergeOptional(\.presetID, field: .presetID, suggestion.presetID, excluding: excludedFields) {
            appliedFields.insert(.presetID)
        }
        if mergeQuantity(suggestion.quantity, excluding: excludedFields) {
            appliedFields.insert(.quantity)
        }
        if mergeOptional(\.purchaseDate, field: .purchaseDate, suggestion.purchaseDate, excluding: excludedFields) {
            appliedFields.insert(.purchaseDate)
        }
        if mergeOptional(\.metal, field: .metal, suggestion.metal, excluding: excludedFields) {
            appliedFields.insert(.metal)
        }
        if mergeOptional(
            \.weightGrams,
            field: .weightGrams,
            suggestion.weightGrams,
            excluding: excludedFields,
            isValid: { $0.isFinite && $0 > 0 }
        ) {
            appliedFields.insert(.weightGrams)
        }
        if mergeOptional(
            \.metalKarat,
            field: .metalKarat,
            suggestion.metalKarat,
            excluding: excludedFields,
            isValid: { (1...24).contains($0) }
        ) {
            appliedFields.insert(.metalKarat)
        }
        if mergeOptional(
            \.finenessPermille,
            field: .finenessPermille,
            suggestion.finenessPermille,
            excluding: excludedFields,
            isValid: { $0.isFinite && $0 > 0 && $0 <= 1_000 }
        ) {
            appliedFields.insert(.finenessPermille)
        }
        if mergeOptional(
            \.gemstoneCaratWeight,
            field: .gemstoneCaratWeight,
            suggestion.gemstoneCaratWeight,
            excluding: excludedFields,
            isValid: { $0.isFinite && $0 > 0 }
        ) {
            appliedFields.insert(.gemstoneCaratWeight)
        }
        if mergeString(
            \.gemstoneClarity,
            field: .gemstoneClarity,
            suggestion.gemstoneClarity,
            excluding: excludedFields
        ) {
            appliedFields.insert(.gemstoneClarity)
        }
        if mergeOptional(
            \.pricePaidMinorUnits,
            field: .pricePaidMinorUnits,
            suggestion.pricePaidMinorUnits,
            excluding: excludedFields,
            isValid: { $0 >= 0 }
        ) {
            appliedFields.insert(.pricePaidMinorUnits)
        }
        if mergeCurrencyCode(suggestion.currencyCode, excluding: excludedFields) {
            appliedFields.insert(.currencyCode)
        }
        if mergeString(\.sellerName, field: .sellerName, suggestion.sellerName, excluding: excludedFields) {
            appliedFields.insert(.sellerName)
        }
        if mergeString(
            \.storageLocationName,
            field: .storageLocationName,
            suggestion.storageLocationName,
            excluding: excludedFields
        ) {
            appliedFields.insert(.storageLocationName)
        }
        if mergeString(
            \.invoiceNumber,
            field: .invoiceNumber,
            suggestion.invoiceNumber,
            excluding: excludedFields
        ) {
            appliedFields.insert(.invoiceNumber)
        }

        return appliedFields
    }

    mutating func clearSuggestedFields(_ fields: Set<Field>) {
        for field in fields where !manuallyEditedFields.contains(field) {
            switch field {
            case .name: name = ""
            case .category: category = nil
            case .presetID: presetID = nil
            case .quantity: quantity = 1
            case .purchaseDate: purchaseDate = nil
            case .metal: metal = nil
            case .weightGrams: weightGrams = nil
            case .metalKarat: metalKarat = nil
            case .finenessPermille: finenessPermille = nil
            case .gemstoneCaratWeight: gemstoneCaratWeight = nil
            case .gemstoneClarity: gemstoneClarity = ""
            case .pricePaidMinorUnits: pricePaidMinorUnits = nil
            case .currencyCode: currencyCode = SupportedAssetCurrency.defaultCurrency.rawValue
            case .sellerName: sellerName = ""
            case .storageLocationName: storageLocationName = ""
            case .invoiceNumber: invoiceNumber = ""
            }
        }
    }

    private mutating func mergeString(
        _ keyPath: WritableKeyPath<Self, String>,
        field: Field,
        _ suggestion: String?,
        excluding excludedFields: Set<Field>,
        isValid: (String) -> Bool = { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    ) -> Bool {
        guard !excludedFields.contains(field),
              !manuallyEditedFields.contains(field),
              self[keyPath: keyPath].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let suggestion,
              isValid(suggestion)
        else { return false }
        self[keyPath: keyPath] = suggestion.trimmingCharacters(in: .whitespacesAndNewlines)
        return true
    }

    private mutating func mergeOptional<Value>(
        _ keyPath: WritableKeyPath<Self, Value?>,
        field: Field,
        _ suggestion: Value?,
        excluding excludedFields: Set<Field>,
        isValid: (Value) -> Bool = { _ in true }
    ) -> Bool {
        guard !excludedFields.contains(field),
              !manuallyEditedFields.contains(field),
              self[keyPath: keyPath] == nil,
              let suggestion,
              isValid(suggestion)
        else { return false }
        self[keyPath: keyPath] = suggestion
        return true
    }

    private mutating func mergeQuantity(
        _ suggestion: Int?,
        excluding excludedFields: Set<Field>
    ) -> Bool {
        guard !excludedFields.contains(.quantity),
              !manuallyEditedFields.contains(.quantity),
              quantity == 1,
              let suggestion,
              suggestion > 0
        else { return false }
        quantity = suggestion
        return true
    }

    private mutating func mergeCurrencyCode(
        _ suggestion: String?,
        excluding excludedFields: Set<Field>
    ) -> Bool {
        guard !excludedFields.contains(.currencyCode),
              !manuallyEditedFields.contains(.currencyCode),
              currencyCode == SupportedAssetCurrency.defaultCurrency.rawValue,
              let suggestion,
              let currency = SupportedAssetCurrency.currency(normalizing: suggestion)
        else { return false }
        currencyCode = currency.rawValue
        return true
    }

}

nonisolated enum AssetSuggestionNormalizer {
    static func displayName(_ value: String) -> String {
        value
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    static func normalizedName(_ value: String) -> String {
        displayName(value)
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
    }
}

nonisolated enum MoneyConverter {
    private static let zeroDecimalCurrencies: Set<String> = [
        "BIF", "CLP", "DJF", "GNF", "JPY", "KMF", "KRW", "PYG", "RWF", "UGX", "VND", "VUV", "XAF", "XOF", "XPF",
    ]
    private static let threeDecimalCurrencies: Set<String> = [
        "BHD", "IQD", "JOD", "KWD", "LYD", "OMR", "TND",
    ]

    static func isSupportedCurrencyCode(_ currencyCode: String) -> Bool {
        let code = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines)
        return code.count == 3
            && code == code.uppercased(with: Locale(identifier: "en_US_POSIX"))
            && Locale.Currency(code).isISOCurrency
    }

    static func minorUnitDigits(for currencyCode: String) -> Int? {
        guard isSupportedCurrencyCode(currencyCode) else { return nil }
        if zeroDecimalCurrencies.contains(currencyCode) { return 0 }
        if threeDecimalCurrencies.contains(currencyCode) { return 3 }
        return 2
    }

    static func minorUnits(from amount: Decimal, currencyCode: String) -> Int64? {
        guard amount >= 0, let digits = minorUnitDigits(for: currencyCode) else { return nil }
        var scaled = amount * powerOfTen(digits)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        guard rounded <= Decimal(Int64.max) else { return nil }
        return NSDecimalNumber(decimal: rounded).int64Value
    }

    static func decimalAmount(from minorUnits: Int64, currencyCode: String) -> Decimal? {
        guard minorUnits >= 0, let digits = minorUnitDigits(for: currencyCode) else { return nil }
        return Decimal(minorUnits) / powerOfTen(digits)
    }

    private static func powerOfTen(_ exponent: Int) -> Decimal {
        (0..<exponent).reduce(Decimal(1)) { value, _ in value * 10 }
    }
}
