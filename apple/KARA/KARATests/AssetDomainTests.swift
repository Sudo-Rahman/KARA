import Foundation
import Testing
@testable import KARA

@Suite("Asset domain")
struct AssetDomainTests {
    @Test("The catalog exposes stable identifiers for every requested asset family")
    func catalogContainsRequestedPresets() {
        let identifiers = Set(AssetCatalog.presets.map(\.id))

        #expect(identifiers.count == AssetCatalog.presets.count)
        #expect(identifiers.isSuperset(of: [
            "gold-bar-1g",
            "gold-bar-2-5g",
            "gold-bar-1kg",
            "gold-coin-20-francs-napoleon",
            "gold-coin-20-francs-marianne-coq",
            "gold-coin-sovereign",
            "gold-coin-britannia-1oz",
            "gold-coin-krugerrand-1oz",
            "gold-coin-maple-leaf-1oz",
            "gold-coin-american-eagle-1oz",
            "gold-coin-vienna-philharmonic-1oz",
            "gold-coin-mexico-50-pesos",
            "silver-bar-1oz",
            "silver-bar-100g",
            "silver-bar-250g",
            "silver-bar-500g",
            "silver-bar-1kg",
            "silver-coin-britannia-1oz",
            "silver-coin-maple-leaf-1oz",
            "silver-coin-american-eagle-1oz",
            "silver-coin-vienna-philharmonic-1oz",
            "platinum-bar-1oz",
            "platinum-bar-100g",
            "palladium-bar-1oz",
            "jewelry-custom",
            "asset-custom",
        ]))
    }

    @Test("Neutral category names preserve their CloudKit raw values")
    func categoryRawValuesRemainBackwardCompatible() {
        #expect(AssetCategory.bar.rawValue == "goldBar")
        #expect(AssetCategory.coin.rawValue == "goldCoin")
        #expect(AssetCategory(rawValue: "goldBar") == .bar)
        #expect(AssetCategory(rawValue: "goldCoin") == .coin)
        #expect(AssetCategory(analysisIdentifier: "bar") == .bar)
        #expect(AssetCategory(analysisIdentifier: "goldCoin") == .coin)
        #expect(AssetCategory.allCases == [.bar, .coin, .jewelry, .custom])
        #expect(AssetCategory.bar.localizationKey == "asset.category.bar")
        #expect(AssetCategory.coin.localizationKey == "asset.category.coin")
    }

    @Test("Catalog filters compose form and metal without losing presentation metadata")
    func catalogFiltersByCategoryAndMetal() throws {
        let silverBars = AssetCatalog.presets(category: .bar, metal: .silver)
        let silverCoins = AssetCatalog.presets(category: .coin, metal: .silver)
        let platinumBars = AssetCatalog.presets(category: .bar, metal: .platinum)
        let palladiumBars = AssetCatalog.presets(category: .bar, metal: .palladium)
        let mapleLeaf = try #require(AssetCatalog.preset(id: "silver-coin-maple-leaf-1oz"))
        let custom = try #require(AssetCatalog.preset(id: "asset-custom"))

        #expect(silverBars.count == 5)
        #expect(silverBars.allSatisfy { $0.category == .bar && $0.metal == .silver })
        #expect(silverCoins.count == 4)
        #expect(silverCoins.allSatisfy { $0.category == .coin && $0.metal == .silver })
        #expect(platinumBars.map(\.id) == ["platinum-bar-1oz", "platinum-bar-100g"])
        #expect(palladiumBars.map(\.id) == ["palladium-bar-1oz"])
        #expect(mapleLeaf.localizationKey == "asset.preset.silver-coin-maple-leaf-1oz")
        #expect(mapleLeaf.fineMetalWeightGrams != nil)
        #expect(!mapleLeaf.isCustomEntry)
        #expect(custom.isCustomEntry)
        #expect(PreciousMetal.silver.localizationKey == "asset.metal.silver")
    }

    @Test("The asset form supports exactly the four official purchase currencies")
    func supportedAssetCurrenciesAreRestricted() {
        #expect(SupportedAssetCurrency.allCases.map(\.rawValue) == ["EUR", "USD", "CHF", "GBP"])
        #expect(SupportedAssetCurrency.currency(normalizing: " eur ") == .euro)
        #expect(SupportedAssetCurrency.currency(normalizing: "jpy") == nil)

        for currency in SupportedAssetCurrency.allCases {
            let draft = AssetDraft(name: "Actif", category: .bar, currencyCode: currency.rawValue)
            #expect(!draft.validationErrors.contains(.invalidCurrencyCode))
        }

        let unsupportedDraft = AssetDraft(name: "Actif", category: .bar, currencyCode: "JPY")
        #expect(unsupportedDraft.validationErrors.contains(.invalidCurrencyCode))
    }

    @Test("Analysis completes fields that remain untouched, including initial defaults")
    func suggestionMergePreservesUserValues() {
        var draft = AssetDraft(sellerName: "Maison Lemoine")
        draft.markAsManuallyEdited(.invoiceNumber)

        draft.merge(suggestion: AssetAnalysisSuggestion(
            name: "Bague solitaire",
            category: .jewelry,
            quantity: 3,
            currencyCode: "USD",
            sellerName: "Autre vendeur",
            invoiceNumber: "INV-42"
        ))

        #expect(draft.name == "Bague solitaire")
        #expect(draft.category == .jewelry)
        #expect(draft.quantity == 3)
        #expect(draft.currencyCode == "USD")
        #expect(draft.sellerName == "Maison Lemoine")
        #expect(draft.invoiceNumber.isEmpty)
    }

    @Test("Catalog presets copy authoritative bullion specifications")
    func catalogCarriesKnownWeightsAndFineness() throws {
        let kilogramBar = try #require(AssetCatalog.preset(id: "gold-bar-1kg"))
        let sovereign = try #require(AssetCatalog.preset(id: "gold-coin-sovereign"))
        let americanEagle = try #require(AssetCatalog.preset(id: "gold-coin-american-eagle-1oz"))
        let silverKilogram = try #require(AssetCatalog.preset(id: "silver-bar-1kg"))
        let platinumOunce = try #require(AssetCatalog.preset(id: "platinum-bar-1oz"))

        #expect(kilogramBar.weightGrams == 1_000)
        #expect(kilogramBar.finenessPermille == 999.9)
        #expect(sovereign.weightGrams == 7.98)
        #expect(sovereign.metalKarat == 22)
        #expect(americanEagle.weightGrams == 33.931)
        #expect(americanEagle.finenessPermille == 916.7)
        #expect(silverKilogram.weightGrams == 1_000)
        #expect(silverKilogram.finenessPermille == 999)
        #expect(platinumOunce.metal == .platinum)
        #expect(platinumOunce.finenessPermille == 999.5)
    }

    @Test("Draft validation rejects missing identity and unsafe numeric values")
    func validatesRequiredAndBoundedFields() {
        let draft = AssetDraft(
            name: "  ",
            quantity: 0,
            weightGrams: -.infinity,
            metalKarat: 25,
            finenessPermille: 1_001,
            gemstoneCaratWeight: -0.1,
            pricePaidMinorUnits: -1,
            currencyCode: "EU"
        )

        #expect(Set(draft.validationErrors) == [
            .missingName,
            .missingCategory,
            .invalidQuantity,
            .invalidWeight,
            .invalidMetalKarat,
            .invalidFineness,
            .invalidGemstoneCaratWeight,
            .invalidPrice,
            .invalidCurrencyCode,
        ])
    }

    @Test("Money conversion honors each currency's minor-unit precision")
    func convertsMoneyWithoutFloatingPointLoss() throws {
        let euros = try #require(Decimal(string: "2390.005"))
        let yen = try #require(Decimal(string: "2390.5"))
        let dinars = try #require(Decimal(string: "12.3454"))

        #expect(MoneyConverter.minorUnits(from: euros, currencyCode: "EUR") == 239_001)
        #expect(MoneyConverter.minorUnits(from: yen, currencyCode: "JPY") == 2_391)
        #expect(MoneyConverter.minorUnits(from: dinars, currencyCode: "KWD") == 12_345)
        #expect(MoneyConverter.decimalAmount(from: 239_001, currencyCode: "EUR") == Decimal(string: "2390.01"))
        #expect(MoneyConverter.minorUnits(from: euros, currencyCode: "eur") == nil)
        #expect(MoneyConverter.minorUnits(from: euros, currencyCode: "ZZZ") == nil)
        #expect(MoneyConverter.isSupportedCurrencyCode("JPY"))
        #expect(!SupportedAssetCurrency.isSupported(code: "JPY"))
    }

    @Test("Suggestion names deduplicate case, accents, width, and whitespace")
    func normalizesReusableSuggestionNames() {
        #expect(AssetSuggestionNormalizer.displayName("  Maison   Lémoine\nParis ") == "Maison Lémoine Paris")
        #expect(AssetSuggestionNormalizer.normalizedName("  MAISON   LÉMOINE ") == "maison lemoine")
        #expect(AssetSuggestionNormalizer.normalizedName("Ｃｏｆｆｒｅ personnel") == "coffre personnel")
    }
}
