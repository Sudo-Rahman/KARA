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
            "vault.market.title",
            "vault.history.period.12-months",
            "vault.history.period.all",
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

    @Test("Vault PDF report has complete English and French copy")
    func vaultPDFReportIsLocalized() throws {
        let requiredKeys = [
            "settings.vault.report.title",
            "settings.vault.report.detail",
            "settings.vault.report.empty-detail",
            "settings.vault.report.generating",
            "settings.vault.report.preview.title",
            "settings.vault.report.preview.share",
            "settings.vault.report.error.title",
            "settings.vault.report.error.body",
            "settings.vault.report.error.retry",
            "settings.vault.report.error.cancel",
            "vault-report.title",
            "vault-report.generated-at",
            "vault-report.page",
            "vault-report.summary.title",
            "vault-report.summary.records",
            "vault-report.summary.objects",
            "vault-report.summary.estimated-value",
            "vault-report.summary.valuation-date",
            "vault-report.summary.purchase-costs",
            "vault-report.summary.gain",
            "vault-report.summary.performance",
            "vault-report.summary.valuation-coverage",
            "vault-report.summary.performance-coverage",
            "vault-report.disclaimer",
            "vault-report.section.composition",
            "vault-report.section.acquisition",
            "vault-report.section.identification",
            "vault-report.section.attachments",
            "vault-report.field.preset",
            "vault-report.field.quantity",
            "vault-report.field.karats",
            "vault-report.field.price-paid",
            "vault-report.field.estimated-value",
            "vault-report.field.gain",
            "vault-report.field.performance",
            "vault-report.field.tags",
            "vault-report.field.created-at",
            "vault-report.field.attachment-type",
            "vault-report.field.filename",
            "vault-report.field.mime-type",
            "vault-report.field.page-count",
            "vault-report.field.file-size",
            "vault-report.field.added-at",
            "vault-report.value.not-available",
        ]

        for language in ["en", "fr"] {
            let strings = try localizedStrings(for: language)
            for key in requiredKeys {
                let value = strings[key]
                #expect(
                    value != nil && value?.isEmpty == false && value != key,
                    "Missing \(language) localization for \(key)"
                )
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
