import Foundation

nonisolated enum AssetCategory: String, CaseIterable, Codable, Sendable {
    case bar = "goldBar"
    case coin = "goldCoin"
    case jewelry
    case custom

    var analysisIdentifier: String {
        switch self {
        case .bar:
            "bar"
        case .coin:
            "coin"
        case .jewelry:
            "jewelry"
        case .custom:
            "custom"
        }
    }

    var localizationKey: String {
        switch self {
        case .bar:
            "asset.category.bar"
        case .coin:
            "asset.category.coin"
        case .jewelry:
            "asset.category.jewelry"
        case .custom:
            "asset.category.custom"
        }
    }

    var isBullion: Bool {
        self == .bar || self == .coin
    }

    init?(analysisIdentifier: String) {
        switch analysisIdentifier.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "bar", Self.bar.rawValue:
            self = .bar
        case "coin", Self.coin.rawValue:
            self = .coin
        case Self.jewelry.rawValue:
            self = .jewelry
        case Self.custom.rawValue:
            self = .custom
        default:
            return nil
        }
    }

    @available(*, deprecated, renamed: "bar")
    static var goldBar: Self { .bar }

    @available(*, deprecated, renamed: "coin")
    static var goldCoin: Self { .coin }
}
nonisolated enum PreciousMetal: String, CaseIterable, Codable, Sendable {
    case gold
    case silver
    case platinum
    case palladium
    case other

    var localizationKey: String {
        "asset.metal.\(rawValue)"
    }
}

nonisolated enum SupportedAssetCurrency: String, CaseIterable, Codable, Identifiable, Sendable {
    case euro = "EUR"
    case usDollar = "USD"
    case swissFranc = "CHF"
    case poundSterling = "GBP"

    static let defaultCurrency = Self.euro

    var id: String { rawValue }

    static func currency(normalizing code: String) -> Self? {
        let normalizedCode = code
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased(with: Locale(identifier: "en_US_POSIX"))
        return Self(rawValue: normalizedCode)
    }

    static func isSupported(code: String) -> Bool {
        Self(rawValue: code) != nil
    }
}

nonisolated enum AssetAttachmentKind: String, CaseIterable, Codable, Sendable {
    case objectPhoto
    case invoice
    case certificate
    case other
}

nonisolated enum AssetAcquisitionMethod: String, CaseIterable, Codable, Identifiable, Sendable {
    case purchase
    case gift
    case inheritance
    case exchange
    case other

    var id: String { rawValue }

    var localizationKey: String {
        "asset.acquisition-method.\(rawValue)"
    }
}

nonisolated struct AssetPreset: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let category: AssetCategory
    let metal: PreciousMetal?
    let weightGrams: Double?
    let metalKarat: Int?
    let finenessPermille: Double?

    var localizationKey: String {
        "asset.preset.\(id)"
    }

    var isCustomEntry: Bool {
        id == "jewelry-custom" || id == "asset-custom"
    }

    var fineMetalWeightGrams: Double? {
        guard let weightGrams, let finenessPermille else { return nil }
        return weightGrams * finenessPermille / 1_000
    }

    init(
        id: String,
        name: String,
        category: AssetCategory,
        metal: PreciousMetal? = nil,
        weightGrams: Double? = nil,
        metalKarat: Int? = nil,
        finenessPermille: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.metal = metal
        self.weightGrams = weightGrams
        self.metalKarat = metalKarat
        self.finenessPermille = finenessPermille
    }
}

nonisolated enum AssetCatalog {
    static func preset(id: String?) -> AssetPreset? {
        guard let id else { return nil }
        return presets.first { $0.id == id }
    }

    static func presets(
        category: AssetCategory? = nil,
        metal: PreciousMetal? = nil
    ) -> [AssetPreset] {
        presets.filter { preset in
            (category == nil || preset.category == category)
                && (metal == nil || preset.metal == metal)
        }
    }
}
