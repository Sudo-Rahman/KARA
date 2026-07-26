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

    @Test("The highest-confidence source wins for a conflicting field")
    func suggestionResolverUsesHighestConfidence() {
        let object = AssetAnalysisSuggestion(
            weightGrams: 100,
            fieldAssessments: [
                .weightGrams: AssetFieldAssessment(
                    confidencePercent: 82,
                    evidenceKind: .visibleText
                )
            ]
        )
        let invoice = AssetAnalysisSuggestion(
            weightGrams: 50,
            fieldAssessments: [
                .weightGrams: AssetFieldAssessment(
                    confidencePercent: 80,
                    evidenceKind: .visibleText
                )
            ]
        )

        let resolved = AssetAnalysisSuggestionResolver.resolve(
            objectPhoto: object,
            invoice: invoice
        )

        #expect(resolved.weightGrams == 100)
        #expect(resolved.assessment(for: .weightGrams)?.confidencePercent == 82)
    }

    @Test("The invoice wins an exact confidence tie")
    func suggestionResolverPrefersInvoiceOnTie() {
        let object = AssetAnalysisSuggestion(weightGrams: 100, confidencePercent: 80)
        let invoice = AssetAnalysisSuggestion(weightGrams: 50, confidencePercent: 80)

        let resolved = AssetAnalysisSuggestionResolver.resolve(
            objectPhoto: object,
            invoice: invoice
        )

        #expect(resolved.weightGrams == 50)
        #expect(resolved.assessment(for: .weightGrams)?.mediaKind == .invoice)
    }

    @Test("A lone low-confidence candidate still prefills")
    func suggestionResolverUsesSingleLowConfidenceCandidate() {
        let object = AssetAnalysisSuggestion(weightGrams: 100, confidencePercent: 15)

        let resolved = AssetAnalysisSuggestionResolver.resolve(
            objectPhoto: object,
            invoice: nil
        )

        #expect(resolved.weightGrams == 100)
        #expect(resolved.assessment(for: .weightGrams)?.confidencePercent == 15)
    }

    @Test("An exact preset supplies reversible catalog specifications")
    func suggestionResolverEnrichesPreset() {
        let object = AssetAnalysisSuggestion(
            presetID: "gold-bar-1oz",
            confidencePercent: 91,
            evidenceKind: .visualIdentification
        )

        let resolved = AssetAnalysisSuggestionResolver.resolve(
            objectPhoto: object,
            invoice: nil
        )

        #expect(resolved.weightGrams == 31.103_476_8)
        #expect(resolved.metalKarat == 24)
        #expect(resolved.finenessPermille == 999.9)
        #expect(resolved.assessment(for: .weightGrams) == AssetFieldAssessment(
            confidencePercent: 91,
            evidenceKind: .catalogDerived,
            mediaKind: .objectPhoto
        ))
    }

    @Test("Money amount and currency always come from the same winning source")
    func suggestionResolverKeepsMoneyAtomic() {
        let object = AssetAnalysisSuggestion(
            pricePaidMinorUnits: 10_000,
            currencyCode: "EUR",
            confidencePercent: 80
        )
        let invoice = AssetAnalysisSuggestion(
            pricePaidMinorUnits: 12_000,
            currencyCode: "CHF",
            confidencePercent: 81
        )

        let resolved = AssetAnalysisSuggestionResolver.resolve(
            objectPhoto: object,
            invoice: invoice
        )

        #expect(resolved.pricePaidMinorUnits == 12_000)
        #expect(resolved.currencyCode == "CHF")
    }

    @Test("A higher-confidence explicit measurement invalidates an incompatible preset")
    func suggestionResolverDropsIncompatiblePreset() {
        let object = AssetAnalysisSuggestion(
            presetID: "gold-bar-1oz",
            confidencePercent: 70,
            evidenceKind: .visualIdentification
        )
        let invoice = AssetAnalysisSuggestion(
            weightGrams: 50,
            confidencePercent: 90
        )

        let resolved = AssetAnalysisSuggestionResolver.resolve(
            objectPhoto: object,
            invoice: invoice
        )

        #expect(resolved.presetID == nil)
        #expect(resolved.weightGrams == 50)
        #expect(resolved.assessment(for: .weightGrams)?.evidenceKind == .visibleText)
    }

    @Test("A manual specification prevents an incompatible AI preset")
    func suggestionResolverPreservesManualSpecificationConsistency() {
        var draft = AssetDraft(weightGrams: 50)
        draft.markAsManuallyEdited(.weightGrams)

        let resolved = AssetAnalysisSuggestionResolver.resolve(
            objectPhoto: AssetAnalysisSuggestion(
                presetID: "gold-bar-1oz",
                confidencePercent: 99,
                evidenceKind: .visualIdentification
            ),
            invoice: nil,
            preserving: draft
        )

        #expect(resolved.presetID == nil)
        #expect(resolved.weightGrams == nil)
        #expect(draft.weightGrams == 50)
    }

    @Test("An existing asset becomes a complete editable draft")
    func createsDraftFromExistingAsset() {
        let asset = Asset(
            name: "Lingot",
            category: .bar,
            quantity: 3,
            metal: .gold,
            sellerName: "Comptoir",
            serialNumber: "A-42",
            acquisitionMethod: .gift,
            tags: ["Famille", "Long terme"]
        )

        let draft = AssetDraft(asset: asset)

        #expect(draft.name == "Lingot")
        #expect(draft.category == .bar)
        #expect(draft.quantity == 3)
        #expect(draft.metal == .gold)
        #expect(draft.sellerName == "Comptoir")
        #expect(draft.serialNumber == "A-42")
        #expect(draft.acquisitionMethod == .gift)
        #expect(draft.tags == ["Famille", "Long terme"])
        #expect(draft.manuallyEditedFields.isEmpty)
    }

    @Test("Analysis suggestions merge metadata and leave manual tags unchanged")
    func mergesInventoryMetadataSuggestions() {
        var draft = AssetDraft(tags: ["Famille"])
        draft.markAsManuallyEdited(.tags)

        let applied = draft.merge(suggestion: AssetAnalysisSuggestion(
            serialNumber: "SERIE-42",
            acquisitionMethod: .inheritance
        ))

        #expect(draft.serialNumber == "SERIE-42")
        #expect(draft.acquisitionMethod == .inheritance)
        #expect(draft.tags == ["Famille"])
        #expect(applied == [.serialNumber, .acquisitionMethod])
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
