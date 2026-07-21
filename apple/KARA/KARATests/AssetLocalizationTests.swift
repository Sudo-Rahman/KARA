import Foundation
import Testing
@testable import KARA

@Suite("Asset localization")
struct AssetLocalizationTests {
    @Test("Measurement copy is explicitly localized in English and French")
    func measurementCopyIsLocalized() throws {
        let requiredKeys = [
            "%@ ct",
            "%@ g",
            "%@ ‰",
            "%lld ct",
            "%lld ct · %@ ‰",
            "ct",
            "‰",
        ]

        for language in ["en", "fr"] {
            let strings = try localizedStrings(for: language)
            for key in requiredKeys {
                #expect(strings[key] != nil, "Missing \(language) localization for \(key)")
            }
        }
    }

    @Test("Currency validation copy names the four supported currencies")
    func currencyValidationCopyMatchesSupportedCurrencies() throws {
        let supportedCodes = SupportedAssetCurrency.allCases.map(\.rawValue)

        for language in ["en", "fr"] {
            let strings = try localizedStrings(for: language)
            let message = try #require(strings["details.validation.invalid-currency"])

            for code in supportedCodes {
                #expect(message.contains(code), "Missing \(code) from the \(language) validation message")
            }
            #expect(!message.contains("ISO"))
        }
    }

    @Test("Every catalog choice has English and French copy")
    func catalogChoicesAreLocalized() throws {
        let requiredKeys = Set(
            AssetCategory.allCases.map(\.localizationKey)
                + PreciousMetal.allCases.map(\.localizationKey)
                + AssetAcquisitionMethod.allCases.map(\.localizationKey)
                + AssetCatalog.presets.map(\.localizationKey)
        )

        for language in ["en", "fr"] {
            let strings = try localizedStrings(for: language)
            for key in requiredKeys {
                #expect(strings[key] != nil, "Missing \(language) localization for \(key)")
            }
        }
    }

    @Test("Vault journey has complete English and French copy")
    func vaultJourneyIsLocalized() throws {
        let requiredKeys = [
            "privacy.action.conceal",
            "privacy.action.reveal",
            "vault.title",
            "vault.metric.estimated-value",
            "vault.gold-live.title",
            "inventory.title",
            "inventory.search.prompt",
            "asset-detail.value.title",
            "asset-detail.documents.title",
            "sale-simulation.title",
            "sale-simulation.disclaimer",
        ]

        for language in ["en", "fr"] {
            let strings = try localizedStrings(for: language)
            for key in requiredKeys {
                let value = strings[key]
                #expect(value != nil && value != key, "Missing \(language) localization for \(key)")
            }
        }
    }

    private func localizedStrings(for language: String) throws -> [String: String] {
        let url = try #require(
            Bundle.main.url(
                forResource: "Localizable",
                withExtension: "strings",
                subdirectory: nil,
                localization: language
            )
        )
        let data = try Data(contentsOf: url)
        return try #require(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String]
        )
    }
}
