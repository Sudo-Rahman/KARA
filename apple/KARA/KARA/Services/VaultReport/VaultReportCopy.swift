import Foundation

nonisolated enum VaultReportCopy {
    static func title(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.title",
            fallback: String(
                localized: "vault-report.title", defaultValue: "Complete vault report"),
            locale: locale)
    }

    static func generatedAt(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.generated-at",
            fallback: String(localized: "vault-report.generated-at", defaultValue: "Generated"),
            locale: locale)
    }

    static func page(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.page",
            fallback: String(localized: "vault-report.page", defaultValue: "Page"),
            locale: locale)
    }

    static func summaryTitle(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.summary.title",
            fallback: String(
                localized: "vault-report.summary.title", defaultValue: "Vault summary"),
            locale: locale)
    }

    static func summaryRecords(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.summary.records",
            fallback: String(
                localized: "vault-report.summary.records", defaultValue: "Active assets"),
            locale: locale)
    }

    static func summaryObjects(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.summary.objects",
            fallback: String(
                localized: "vault-report.summary.objects", defaultValue: "Total objects"),
            locale: locale)
    }

    static func summaryEstimatedValue(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.summary.estimated-value",
            fallback: String(
                localized: "vault-report.summary.estimated-value",
                defaultValue: "Estimated current value"),
            locale: locale)
    }

    static func summaryValuationDate(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.summary.valuation-date",
            fallback: String(
                localized: "vault-report.summary.valuation-date", defaultValue: "Valuation date"),
            locale: locale)
    }

    static func summaryPurchaseCosts(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.summary.purchase-costs",
            fallback: String(
                localized: "vault-report.summary.purchase-costs",
                defaultValue: "Purchase costs by currency"
            ), locale: locale)
    }

    static func summaryGain(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.summary.gain",
            fallback: String(
                localized: "vault-report.summary.gain", defaultValue: "Unrealized gain"),
            locale: locale)
    }

    static func summaryPerformance(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.summary.performance",
            fallback: String(
                localized: "vault-report.summary.performance", defaultValue: "Performance"),
            locale: locale)
    }

    static func summaryValuationCoverage(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.summary.valuation-coverage",
            fallback: String(
                localized: "vault-report.summary.valuation-coverage",
                defaultValue: "Valuation coverage"),
            locale: locale)
    }

    static func summaryPerformanceCoverage(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.summary.performance-coverage",
            fallback: String(
                localized: "vault-report.summary.performance-coverage",
                defaultValue: "Performance coverage"
            ), locale: locale)
    }

    static func disclaimer(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.disclaimer",
            fallback: String(
                localized: "vault-report.disclaimer",
                defaultValue: "Valuations are indicative estimates as of the date shown."),
            locale: locale)
    }

    static func sectionComposition(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.section.composition",
            fallback: String(
                localized: "vault-report.section.composition", defaultValue: "Composition"),
            locale: locale)
    }

    static func sectionAcquisition(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.section.acquisition",
            fallback: String(
                localized: "vault-report.section.acquisition", defaultValue: "Acquisition"),
            locale: locale)
    }

    static func sectionIdentification(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.section.identification",
            fallback: String(
                localized: "vault-report.section.identification", defaultValue: "Identification"),
            locale: locale)
    }

    static func sectionAttachments(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.section.attachments",
            fallback: String(
                localized: "vault-report.section.attachments", defaultValue: "Attachments"),
            locale: locale)
    }

    static func fieldPreset(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.field.preset",
            fallback: String(
                localized: "vault-report.field.preset", defaultValue: "Catalog preset"),
            locale: locale)
    }

    static func fieldQuantity(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.field.quantity",
            fallback: String(localized: "vault-report.field.quantity", defaultValue: "Quantity"),
            locale: locale)
    }

    static func fieldKarats(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.field.karats",
            fallback: String(localized: "vault-report.field.karats", defaultValue: "Karats"),
            locale: locale)
    }

    static func fieldPricePaid(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.field.price-paid",
            fallback: String(
                localized: "vault-report.field.price-paid", defaultValue: "Price paid"),
            locale: locale)
    }

    static func fieldEstimatedValue(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.field.estimated-value",
            fallback: String(
                localized: "vault-report.field.estimated-value", defaultValue: "Estimated value"),
            locale: locale)
    }

    static func fieldGain(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.field.gain",
            fallback: String(localized: "vault-report.field.gain", defaultValue: "Gain"),
            locale: locale)
    }

    static func fieldPerformance(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.field.performance",
            fallback: String(
                localized: "vault-report.field.performance", defaultValue: "Performance"),
            locale: locale)
    }

    static func fieldTags(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.field.tags",
            fallback: String(localized: "vault-report.field.tags", defaultValue: "Tags"),
            locale: locale)
    }

    static func fieldCreatedAt(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.field.created-at",
            fallback: String(localized: "vault-report.field.created-at", defaultValue: "Created"),
            locale: locale)
    }

    static func fieldAttachmentType(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.field.attachment-type",
            fallback: String(localized: "vault-report.field.attachment-type", defaultValue: "Type"),
            locale: locale)
    }

    static func fieldFilename(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.field.filename",
            fallback: String(localized: "vault-report.field.filename", defaultValue: "Filename"),
            locale: locale)
    }

    static func fieldMIMEType(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.field.mime-type",
            fallback: String(localized: "vault-report.field.mime-type", defaultValue: "MIME type"),
            locale: locale)
    }

    static func fieldPageCount(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.field.page-count",
            fallback: String(localized: "vault-report.field.page-count", defaultValue: "Pages"),
            locale: locale)
    }

    static func fieldFileSize(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.field.file-size",
            fallback: String(localized: "vault-report.field.file-size", defaultValue: "File size"),
            locale: locale)
    }

    static func fieldAddedAt(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.field.added-at",
            fallback: String(localized: "vault-report.field.added-at", defaultValue: "Added"),
            locale: locale)
    }

    static func notAvailable(locale: Locale) -> String {
        localizedDynamic(
            "vault-report.value.not-available",
            fallback: String(
                localized: "vault-report.value.not-available", defaultValue: "Not available"),
            locale: locale)
    }

    static func fieldCategory(locale: Locale) -> String {
        localizedDynamic(
            "asset-detail.field.category",
            fallback: String(localized: "asset-detail.field.category", defaultValue: "Category"),
            locale: locale)
    }

    static func fieldMetal(locale: Locale) -> String {
        localizedDynamic(
            "asset-detail.field.metal",
            fallback: String(localized: "asset-detail.field.metal", defaultValue: "Metal"),
            locale: locale)
    }

    static func fieldGrossWeight(locale: Locale) -> String {
        localizedDynamic(
            "asset-detail.field.gross-weight",
            fallback: String(
                localized: "asset-detail.field.gross-weight", defaultValue: "Gross weight / object"),
            locale: locale)
    }

    static func fieldPurity(locale: Locale) -> String {
        localizedDynamic(
            "asset-detail.field.purity",
            fallback: String(localized: "asset-detail.field.purity", defaultValue: "Purity"),
            locale: locale)
    }

    static func fieldGemstoneWeight(locale: Locale) -> String {
        localizedDynamic(
            "asset-detail.field.gemstone-weight",
            fallback: String(
                localized: "asset-detail.field.gemstone-weight", defaultValue: "Gemstone weight"),
            locale: locale)
    }

    static func fieldGemstoneClarity(locale: Locale) -> String {
        localizedDynamic(
            "asset-detail.field.gemstone-clarity",
            fallback: String(
                localized: "asset-detail.field.gemstone-clarity", defaultValue: "Gemstone clarity"),
            locale: locale)
    }

    static func fieldPurchaseDate(locale: Locale) -> String {
        localizedDynamic(
            "asset-detail.field.purchase-date",
            fallback: String(
                localized: "asset-detail.field.purchase-date", defaultValue: "Acquisition date"),
            locale: locale)
    }

    static func fieldSeller(locale: Locale) -> String {
        localizedDynamic(
            "asset-detail.field.seller",
            fallback: String(localized: "asset-detail.field.seller", defaultValue: "Seller"),
            locale: locale)
    }

    static func fieldStorage(locale: Locale) -> String {
        localizedDynamic(
            "asset-detail.field.storage",
            fallback: String(
                localized: "asset-detail.field.storage", defaultValue: "Storage location"),
            locale: locale)
    }

    static func fieldInvoice(locale: Locale) -> String {
        localizedDynamic(
            "asset-detail.field.invoice",
            fallback: String(
                localized: "asset-detail.field.invoice", defaultValue: "Invoice number"),
            locale: locale)
    }

    static func fieldSerialNumber(locale: Locale) -> String {
        localizedDynamic(
            "asset-detail.field.serial-number",
            fallback: String(
                localized: "asset-detail.field.serial-number", defaultValue: "Serial number"),
            locale: locale)
    }

    static func fieldAcquisitionMethod(locale: Locale) -> String {
        localizedDynamic(
            "asset-detail.field.acquisition-method",
            fallback: String(
                localized: "asset-detail.field.acquisition-method",
                defaultValue: "Acquisition method"), locale: locale)
    }

    static func fieldUpdatedAt(locale: Locale) -> String {
        localizedDynamic(
            "asset-detail.field.updated",
            fallback: String(localized: "asset-detail.field.updated", defaultValue: "Last updated"),
            locale: locale)
    }

    static func category(_ category: AssetCategory, locale: Locale) -> String {
        switch category {
        case .bar:
            localizedDynamic(
                "asset.category.bar",
                fallback: String(localized: "asset.category.bar", defaultValue: "Bullion bar"),
                locale: locale)
        case .coin:
            localizedDynamic(
                "asset.category.coin",
                fallback: String(localized: "asset.category.coin", defaultValue: "Coin"),
                locale: locale)
        case .jewelry:
            localizedDynamic(
                "asset.category.jewelry",
                fallback: String(localized: "asset.category.jewelry", defaultValue: "Jewelry"),
                locale: locale)
        case .custom:
            localizedDynamic(
                "asset.category.custom",
                fallback: String(localized: "asset.category.custom", defaultValue: "Other asset"),
                locale: locale)
        }
    }

    static func metal(_ metal: PreciousMetal, locale: Locale) -> String {
        switch metal {
        case .gold:
            localizedDynamic(
                "asset.metal.gold",
                fallback: String(localized: "asset.metal.gold", defaultValue: "Gold"),
                locale: locale)
        case .silver:
            localizedDynamic(
                "asset.metal.silver",
                fallback: String(localized: "asset.metal.silver", defaultValue: "Silver"),
                locale: locale)
        case .platinum:
            localizedDynamic(
                "asset.metal.platinum",
                fallback: String(localized: "asset.metal.platinum", defaultValue: "Platinum"),
                locale: locale)
        case .palladium:
            localizedDynamic(
                "asset.metal.palladium",
                fallback: String(localized: "asset.metal.palladium", defaultValue: "Palladium"),
                locale: locale)
        case .other:
            localizedDynamic(
                "asset.metal.other",
                fallback: String(localized: "asset.metal.other", defaultValue: "Other"),
                locale: locale)
        }
    }

    static func acquisitionMethod(
        _ method: AssetAcquisitionMethod,
        locale: Locale
    ) -> String {
        switch method {
        case .purchase:
            localizedDynamic(
                "asset.acquisition-method.purchase",
                fallback: String(
                    localized: "asset.acquisition-method.purchase", defaultValue: "Purchase"),
                locale: locale)
        case .gift:
            localizedDynamic(
                "asset.acquisition-method.gift",
                fallback: String(localized: "asset.acquisition-method.gift", defaultValue: "Gift"),
                locale: locale)
        case .inheritance:
            localizedDynamic(
                "asset.acquisition-method.inheritance",
                fallback: String(
                    localized: "asset.acquisition-method.inheritance", defaultValue: "Inheritance"),
                locale: locale)
        case .exchange:
            localizedDynamic(
                "asset.acquisition-method.exchange",
                fallback: String(
                    localized: "asset.acquisition-method.exchange", defaultValue: "Exchange"),
                locale: locale)
        case .other:
            localizedDynamic(
                "asset.acquisition-method.other",
                fallback: String(
                    localized: "asset.acquisition-method.other", defaultValue: "Other"),
                locale: locale)
        }
    }

    static func attachmentKind(
        _ kind: AssetAttachmentKind,
        locale: Locale
    ) -> String {
        switch kind {
        case .objectPhoto:
            localizedDynamic(
                "documents.kind.objectPhoto",
                fallback: String(
                    localized: "documents.kind.objectPhoto", defaultValue: "Photos",
                    table: "AssetDocuments"), table: "AssetDocuments", locale: locale)
        case .invoice:
            localizedDynamic(
                "documents.kind.invoice",
                fallback: String(
                    localized: "documents.kind.invoice", defaultValue: "Invoices",
                    table: "AssetDocuments"), table: "AssetDocuments", locale: locale)
        case .certificate:
            localizedDynamic(
                "documents.kind.certificate",
                fallback: String(
                    localized: "documents.kind.certificate", defaultValue: "Certificates",
                    table: "AssetDocuments"), table: "AssetDocuments", locale: locale)
        case .other:
            localizedDynamic(
                "documents.kind.other",
                fallback: String(
                    localized: "documents.kind.other", defaultValue: "Other documents",
                    table: "AssetDocuments"), table: "AssetDocuments", locale: locale)
        }
    }

    static func preset(_ preset: VaultReportPresetSnapshot, locale: Locale) -> String {
        localizedDynamic(
            preset.localizationKey,
            fallback: preset.fallbackName,
            locale: locale
        )
    }

    private static func localizedDynamic(
        _ key: String,
        fallback: String,
        table: String = "Localizable",
        locale: Locale
    ) -> String {
        let bundle = localizedBundle(for: locale) ?? .main
        return bundle.localizedString(
            forKey: key,
            value: fallback,
            table: table
        )
    }

    private static func localizedBundle(for locale: Locale) -> Bundle? {
        let preferences = [locale.identifier, locale.language.languageCode?.identifier]
            .compactMap { $0 }
        guard
            let localization = Bundle.preferredLocalizations(
                from: Bundle.main.localizations,
                forPreferences: preferences
            ).first,
            let path = Bundle.main.path(forResource: localization, ofType: "lproj")
        else {
            return nil
        }
        return Bundle(path: path)
    }
}
