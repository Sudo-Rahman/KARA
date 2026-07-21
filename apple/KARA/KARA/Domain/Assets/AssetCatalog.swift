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
    static let presets: [AssetPreset] = [
        goldBar(id: "gold-bar-1g", name: "Lingotin or 1 g", grams: 1),
        goldBar(id: "gold-bar-2-5g", name: "Lingotin or 2,5 g", grams: 2.5),
        goldBar(id: "gold-bar-5g", name: "Lingotin or 5 g", grams: 5),
        goldBar(id: "gold-bar-10g", name: "Lingotin or 10 g", grams: 10),
        goldBar(id: "gold-bar-20g", name: "Lingotin or 20 g", grams: 20),
        goldBar(id: "gold-bar-1oz", name: "Lingotin or 1 oz", grams: 31.103_476_8),
        goldBar(id: "gold-bar-50g", name: "Lingotin or 50 g", grams: 50),
        goldBar(id: "gold-bar-100g", name: "Lingot or 100 g", grams: 100),
        goldBar(id: "gold-bar-250g", name: "Lingot or 250 g", grams: 250),
        goldBar(id: "gold-bar-500g", name: "Lingot or 500 g", grams: 500),
        goldBar(id: "gold-bar-1kg", name: "Lingot or 1 kg", grams: 1_000),
        goldCoin(
            id: "gold-coin-20-francs-napoleon",
            name: "20 Francs Napoléon",
            grams: 6.451_61,
            fineness: 900
        ),
        goldCoin(
            id: "gold-coin-20-francs-marianne-coq",
            name: "20 Francs Marianne Coq",
            grams: 6.451_61,
            fineness: 900
        ),
        goldCoin(
            id: "gold-coin-sovereign",
            name: "Souverain britannique",
            grams: 7.98,
            karat: 22,
            fineness: 916.7
        ),
        goldCoin(
            id: "gold-coin-britannia-1-10oz",
            name: "Britannia or 1/10 oz",
            grams: 3.11,
            karat: 24,
            fineness: 999.9
        ),
        goldCoin(
            id: "gold-coin-britannia-1-4oz",
            name: "Britannia or 1/4 oz",
            grams: 7.78,
            karat: 24,
            fineness: 999.9
        ),
        goldCoin(
            id: "gold-coin-britannia-1-2oz",
            name: "Britannia or 1/2 oz",
            grams: 15.60,
            karat: 24,
            fineness: 999.9
        ),
        goldCoin(
            id: "gold-coin-britannia-1oz",
            name: "Britannia or 1 oz",
            grams: 31.103_476_8,
            karat: 24,
            fineness: 999.9
        ),
        goldCoin(
            id: "gold-coin-krugerrand-1oz",
            name: "Krugerrand or 1 oz",
            grams: 33.93,
            karat: 22,
            fineness: 916.7
        ),
        goldCoin(
            id: "gold-coin-maple-leaf-1oz",
            name: "Maple Leaf or 1 oz",
            grams: 31.103_476_8,
            karat: 24,
            fineness: 999.9
        ),
        goldCoin(
            id: "gold-coin-american-eagle-1oz",
            name: "American Eagle or 1 oz",
            grams: 33.931,
            karat: 22,
            fineness: 916.7
        ),
        goldCoin(
            id: "gold-coin-vienna-philharmonic-1oz",
            name: "Philharmonique de Vienne or 1 oz",
            grams: 31.103_476_8,
            karat: 24,
            fineness: 999.9
        ),
        goldCoin(
            id: "gold-coin-mexico-50-pesos",
            name: "50 Pesos mexicains",
            grams: 41.666,
            fineness: 900
        ),
        bullionBar(
            id: "silver-bar-1oz",
            name: "Lingot argent 1 oz",
            metal: .silver,
            grams: 31.103_476_8,
            fineness: 999
        ),
        bullionBar(
            id: "silver-bar-100g",
            name: "Lingot argent 100 g",
            metal: .silver,
            grams: 100,
            fineness: 999
        ),
        bullionBar(
            id: "silver-bar-250g",
            name: "Lingot argent 250 g",
            metal: .silver,
            grams: 250,
            fineness: 999
        ),
        bullionBar(
            id: "silver-bar-500g",
            name: "Lingot argent 500 g",
            metal: .silver,
            grams: 500,
            fineness: 999
        ),
        bullionBar(
            id: "silver-bar-1kg",
            name: "Lingot argent 1 kg",
            metal: .silver,
            grams: 1_000,
            fineness: 999
        ),
        bullionCoin(
            id: "silver-coin-britannia-1oz",
            name: "Britannia argent 1 oz",
            metal: .silver,
            grams: 31.103_476_8,
            fineness: 999
        ),
        bullionCoin(
            id: "silver-coin-maple-leaf-1oz",
            name: "Maple Leaf argent 1 oz",
            metal: .silver,
            grams: 31.103_476_8,
            fineness: 999.9
        ),
        bullionCoin(
            id: "silver-coin-american-eagle-1oz",
            name: "American Eagle argent 1 oz",
            metal: .silver,
            grams: 31.103_476_8,
            fineness: 999
        ),
        bullionCoin(
            id: "silver-coin-vienna-philharmonic-1oz",
            name: "Philharmonique de Vienne argent 1 oz",
            metal: .silver,
            grams: 31.103_476_8,
            fineness: 999
        ),
        bullionBar(
            id: "platinum-bar-1oz",
            name: "Lingot platine 1 oz",
            metal: .platinum,
            grams: 31.103_476_8,
            fineness: 999.5
        ),
        bullionBar(
            id: "platinum-bar-100g",
            name: "Lingot platine 100 g",
            metal: .platinum,
            grams: 100,
            fineness: 999.5
        ),
        bullionBar(
            id: "palladium-bar-1oz",
            name: "Lingot palladium 1 oz",
            metal: .palladium,
            grams: 31.103_476_8,
            fineness: 999.5
        ),
        AssetPreset(
            id: "jewelry-custom",
            name: "Bijou",
            category: .jewelry
        ),
        AssetPreset(
            id: "asset-custom",
            name: "Autre",
            category: .custom
        ),
    ]

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

    private static func goldBar(id: String, name: String, grams: Double) -> AssetPreset {
        bullionBar(
            id: id,
            name: name,
            metal: .gold,
            grams: grams,
            karat: 24,
            fineness: 999.9
        )
    }

    private static func goldCoin(
        id: String,
        name: String,
        grams: Double,
        karat: Int? = nil,
        fineness: Double
    ) -> AssetPreset {
        bullionCoin(
            id: id,
            name: name,
            metal: .gold,
            grams: grams,
            karat: karat,
            fineness: fineness
        )
    }

    private static func bullionBar(
        id: String,
        name: String,
        metal: PreciousMetal,
        grams: Double,
        karat: Int? = nil,
        fineness: Double
    ) -> AssetPreset {
        AssetPreset(
            id: id,
            name: name,
            category: .bar,
            metal: metal,
            weightGrams: grams,
            metalKarat: karat,
            finenessPermille: fineness
        )
    }

    private static func bullionCoin(
        id: String,
        name: String,
        metal: PreciousMetal,
        grams: Double,
        karat: Int? = nil,
        fineness: Double
    ) -> AssetPreset {
        AssetPreset(
            id: id,
            name: name,
            category: .coin,
            metal: metal,
            weightGrams: grams,
            metalKarat: karat,
            finenessPermille: fineness
        )
    }
}
