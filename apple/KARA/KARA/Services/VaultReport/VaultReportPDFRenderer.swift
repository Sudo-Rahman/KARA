import Foundation
import UIKit

nonisolated enum VaultReportPDFRendererError: Error, Equatable, Sendable {
    case emptyDocument
}

nonisolated struct VaultReportPDFRenderer: Sendable {
    private let snapshot: VaultReportSnapshot
    private let locale: Locale
    private let generatedAt: Date

    init(
        snapshot: VaultReportSnapshot,
        locale: Locale,
        generatedAt: Date
    ) {
        self.snapshot = snapshot
        self.locale = locale
        self.generatedAt = generatedAt
    }

    func render() throws -> Data {
        try Task.checkCancellation()

        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [
            kCGPDFContextCreator as String: "KARA",
            kCGPDFContextTitle as String: VaultReportCopy.title(locale: locale),
        ]
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(origin: .zero, size: VaultReportPDFLayout.pageSize),
            format: format
        )

        var renderingError: Error?
        let data = renderer.pdfData { context in
            let composer = VaultReportPDFComposer(
                context: context,
                locale: locale,
                generatedAt: generatedAt
            )
            do {
                try drawReport(using: composer)
            } catch {
                renderingError = error
            }
        }

        try Task.checkCancellation()
        if let renderingError {
            throw renderingError
        }
        guard !data.isEmpty else {
            throw VaultReportPDFRendererError.emptyDocument
        }
        return data
    }

    private func drawReport(using composer: VaultReportPDFComposer) throws {
        try Task.checkCancellation()
        try composer.beginPage()
        try composer.drawDocumentTitle(VaultReportCopy.summaryTitle(locale: locale))

        let summary = summaryFields()
        for field in summary {
            try Task.checkCancellation()
            try composer.drawField(label: field.label, value: field.value)
        }

        try composer.drawNotice(VaultReportCopy.disclaimer(locale: locale))

        for asset in snapshot.assets {
            try Task.checkCancellation()
            try composer.beginAssetPage(asset.name)
            try draw(asset: asset, using: composer)
            composer.endAsset()
        }
    }

    private func summaryFields() -> [VaultReportField] {
        let coverage = snapshot.valuation.coverage
        let purchaseCosts = snapshot.purchaseCosts.map {
            VaultFormatters.reportCurrency(
                $0.amount,
                code: $0.currencyCode,
                locale: locale
            )
        }.joined(separator: " · ")

        return [
            VaultReportField(
                label: VaultReportCopy.generatedAt(locale: locale),
                value: VaultFormatters.reportDateTime(generatedAt, locale: locale)
            ),
            VaultReportField(
                label: VaultReportCopy.summaryRecords(locale: locale),
                value: VaultFormatters.reportInteger(snapshot.recordCount, locale: locale)
            ),
            VaultReportField(
                label: VaultReportCopy.summaryObjects(locale: locale),
                value: VaultFormatters.reportInteger(snapshot.objectCount, locale: locale)
            ),
            VaultReportField(
                label: VaultReportCopy.summaryEstimatedValue(locale: locale),
                value: coverage.valuedRecordCount > 0
                    ? VaultFormatters.reportCurrency(
                        snapshot.valuation.totalEstimatedValueEUR,
                        code: "EUR",
                        locale: locale
                    )
                    : VaultReportCopy.notAvailable(locale: locale)
            ),
            VaultReportField(
                label: VaultReportCopy.summaryValuationDate(locale: locale),
                value: VaultFormatters.reportDateTime(snapshot.valuationAsOf, locale: locale)
            ),
            VaultReportField(
                label: VaultReportCopy.summaryPurchaseCosts(locale: locale),
                value: purchaseCosts.isEmpty
                    ? VaultReportCopy.notAvailable(locale: locale)
                    : purchaseCosts
            ),
            VaultReportField(
                label: VaultReportCopy.summaryGain(locale: locale),
                value: snapshot.valuation.totalGainEUR.map {
                    VaultFormatters.reportCurrency(
                        $0,
                        code: "EUR",
                        locale: locale,
                        showsPositiveSign: true
                    )
                } ?? VaultReportCopy.notAvailable(locale: locale)
            ),
            VaultReportField(
                label: VaultReportCopy.summaryPerformance(locale: locale),
                value: snapshot.valuation.gainPercentage.map {
                    VaultFormatters.reportPercentage(
                        $0,
                        locale: locale,
                        showsPositiveSign: true
                    )
                } ?? VaultReportCopy.notAvailable(locale: locale)
            ),
            VaultReportField(
                label: VaultReportCopy.summaryValuationCoverage(locale: locale),
                value: coverageText(
                    part: coverage.valuedRecordCount,
                    whole: coverage.totalRecordCount,
                    percentage: coverage.valuationPercentage
                )
            ),
            VaultReportField(
                label: VaultReportCopy.summaryPerformanceCoverage(locale: locale),
                value: coverageText(
                    part: coverage.performanceRecordCount,
                    whole: coverage.totalRecordCount,
                    percentage: coverage.performancePercentage
                )
            ),
        ]
    }

    private func draw(
        asset: VaultReportAssetSnapshot,
        using composer: VaultReportPDFComposer
    ) throws {
        try Task.checkCancellation()
        try composer.drawAssetValuations([
            VaultReportField(
                label: VaultReportCopy.fieldEstimatedValue(locale: locale),
                value: asset.valuation.estimatedValueEUR.map {
                    VaultFormatters.reportCurrency($0, code: "EUR", locale: locale)
                } ?? VaultReportCopy.notAvailable(locale: locale)
            ),
            VaultReportField(
                label: VaultReportCopy.fieldGain(locale: locale),
                value: asset.valuation.gainEUR.map {
                    VaultFormatters.reportCurrency(
                        $0,
                        code: "EUR",
                        locale: locale,
                        showsPositiveSign: true
                    )
                } ?? VaultReportCopy.notAvailable(locale: locale)
            ),
            VaultReportField(
                label: VaultReportCopy.fieldPerformance(locale: locale),
                value: asset.valuation.gainPercentage.map {
                    VaultFormatters.reportPercentage(
                        $0,
                        locale: locale,
                        showsPositiveSign: true
                    )
                } ?? VaultReportCopy.notAvailable(locale: locale)
            ),
        ])

        try drawSection(
            title: VaultReportCopy.sectionIdentification(locale: locale),
            fields: identificationFields(for: asset),
            using: composer
        )
        try drawSection(
            title: VaultReportCopy.sectionComposition(locale: locale),
            fields: compositionFields(for: asset),
            using: composer
        )
        try drawSection(
            title: VaultReportCopy.sectionAcquisition(locale: locale),
            fields: acquisitionFields(for: asset),
            using: composer
        )

        guard let firstAttachment = asset.attachments.first else { return }
        try Task.checkCancellation()
        let firstAttachmentFields = attachmentFields(for: firstAttachment)
        guard let firstAttachmentField = firstAttachmentFields.first else { return }
        let attachmentsTitle = VaultReportCopy.sectionAttachments(locale: locale)
        try composer.prepareSection(
            title: attachmentsTitle,
            firstField: firstAttachmentField
        )
        try composer.drawSectionTitle(attachmentsTitle)
        for (index, attachment) in asset.attachments.enumerated() {
            try Task.checkCancellation()
            let fields = index == 0
                ? firstAttachmentFields
                : attachmentFields(for: attachment)
            if index > 0, let firstField = fields.first {
                try composer.prepareAttachment(firstField: firstField)
                try composer.drawSeparator()
            }
            for (fieldIndex, field) in fields.enumerated() {
                try Task.checkCancellation()
                try composer.drawField(
                    label: field.label,
                    value: field.value,
                    keepWithPrevious: fieldIndex == 0
                )
            }
        }
    }

    private func drawSection(
        title: String,
        fields: [VaultReportField],
        using composer: VaultReportPDFComposer
    ) throws {
        try Task.checkCancellation()
        guard let firstField = fields.first else { return }
        try composer.prepareSection(title: title, firstField: firstField)
        try composer.drawSectionTitle(title)
        for (index, field) in fields.enumerated() {
            try Task.checkCancellation()
            try composer.drawField(
                label: field.label,
                value: field.value,
                keepWithPrevious: index == 0
            )
        }
    }

    private func identificationFields(
        for asset: VaultReportAssetSnapshot
    ) -> [VaultReportField] {
        var fields = [
            VaultReportField(
                label: VaultReportCopy.fieldCategory(locale: locale),
                value: VaultReportCopy.category(asset.category, locale: locale)
            ),
            VaultReportField(
                label: VaultReportCopy.fieldQuantity(locale: locale),
                value: VaultFormatters.reportInteger(asset.quantity, locale: locale)
            ),
        ]
        if let preset = asset.preset {
            fields.append(VaultReportField(
                label: VaultReportCopy.fieldPreset(locale: locale),
                value: VaultReportCopy.preset(preset, locale: locale)
            ))
        }
        append(
            asset.invoiceNumber,
            label: VaultReportCopy.fieldInvoice(locale: locale),
            to: &fields
        )
        append(
            asset.serialNumber,
            label: VaultReportCopy.fieldSerialNumber(locale: locale),
            to: &fields
        )
        fields.append(VaultReportField(
            label: VaultReportCopy.fieldCreatedAt(locale: locale),
            value: VaultFormatters.reportDateTime(asset.createdAt, locale: locale)
        ))
        fields.append(VaultReportField(
            label: VaultReportCopy.fieldUpdatedAt(locale: locale),
            value: VaultFormatters.reportDateTime(asset.updatedAt, locale: locale)
        ))
        return fields
    }

    private func compositionFields(
        for asset: VaultReportAssetSnapshot
    ) -> [VaultReportField] {
        var fields: [VaultReportField] = []
        if let metal = asset.metal {
            fields.append(VaultReportField(
                label: VaultReportCopy.fieldMetal(locale: locale),
                value: VaultReportCopy.metal(metal, locale: locale)
            ))
        }
        if let weight = asset.weightGrams {
            fields.append(VaultReportField(
                label: VaultReportCopy.fieldGrossWeight(locale: locale),
                value: VaultFormatters.reportWeight(weight, locale: locale)
            ))
        }
        if let fineness = asset.finenessPermille {
            fields.append(VaultReportField(
                label: VaultReportCopy.fieldPurity(locale: locale),
                value: "\(VaultFormatters.reportDecimal(fineness, locale: locale, maximumFractionDigits: 1))\u{00A0}‰"
            ))
        }
        if let karats = asset.metalKarat {
            fields.append(VaultReportField(
                label: VaultReportCopy.fieldKarats(locale: locale),
                value: "\(VaultFormatters.reportInteger(karats, locale: locale))\u{00A0}K"
            ))
        }
        if let gemstoneWeight = asset.gemstoneCaratWeight {
            fields.append(VaultReportField(
                label: VaultReportCopy.fieldGemstoneWeight(locale: locale),
                value: "\(VaultFormatters.reportDecimal(gemstoneWeight, locale: locale))\u{00A0}ct"
            ))
        }
        append(
            asset.gemstoneClarity,
            label: VaultReportCopy.fieldGemstoneClarity(locale: locale),
            to: &fields
        )
        return fields
    }

    private func acquisitionFields(
        for asset: VaultReportAssetSnapshot
    ) -> [VaultReportField] {
        var fields: [VaultReportField] = []
        if let purchaseDate = asset.purchaseDate {
            fields.append(VaultReportField(
                label: VaultReportCopy.fieldPurchaseDate(locale: locale),
                value: VaultFormatters.reportDate(purchaseDate, locale: locale)
            ))
        }
        if let pricePaid = asset.pricePaid {
            fields.append(VaultReportField(
                label: VaultReportCopy.fieldPricePaid(locale: locale),
                value: VaultFormatters.reportCurrency(
                    pricePaid.amount,
                    code: pricePaid.currencyCode,
                    locale: locale
                )
            ))
        }
        append(
            asset.sellerName,
            label: VaultReportCopy.fieldSeller(locale: locale),
            to: &fields
        )
        append(
            asset.storageLocationName,
            label: VaultReportCopy.fieldStorage(locale: locale),
            to: &fields
        )
        if let method = asset.acquisitionMethod {
            fields.append(VaultReportField(
                label: VaultReportCopy.fieldAcquisitionMethod(locale: locale),
                value: VaultReportCopy.acquisitionMethod(method, locale: locale)
            ))
        }
        if !asset.tags.isEmpty {
            fields.append(VaultReportField(
                label: VaultReportCopy.fieldTags(locale: locale),
                value: asset.tags.joined(separator: ", ")
            ))
        }
        return fields
    }

    private func attachmentFields(
        for attachment: VaultReportAttachmentSnapshot
    ) -> [VaultReportField] {
        var fields = [
            VaultReportField(
                label: VaultReportCopy.fieldAttachmentType(locale: locale),
                value: VaultReportCopy.attachmentKind(attachment.kind, locale: locale)
            ),
            VaultReportField(
                label: VaultReportCopy.fieldFilename(locale: locale),
                value: attachment.filename
            ),
            VaultReportField(
                label: VaultReportCopy.fieldMIMEType(locale: locale),
                value: attachment.mimeType
            ),
        ]
        if let pageCount = attachment.pageCount {
            fields.append(VaultReportField(
                label: VaultReportCopy.fieldPageCount(locale: locale),
                value: VaultFormatters.reportInteger(pageCount, locale: locale)
            ))
        }
        fields.append(VaultReportField(
            label: VaultReportCopy.fieldFileSize(locale: locale),
            value: attachment.byteCount.map {
                VaultFormatters.reportByteCount($0, locale: locale)
            } ?? VaultReportCopy.notAvailable(locale: locale)
        ))
        fields.append(VaultReportField(
            label: VaultReportCopy.fieldAddedAt(locale: locale),
            value: VaultFormatters.reportDateTime(attachment.createdAt, locale: locale)
        ))
        return fields
    }

    private func coverageText(part: Int, whole: Int, percentage: Decimal?) -> String {
        let fraction = "\(VaultFormatters.reportInteger(part, locale: locale))/\(VaultFormatters.reportInteger(whole, locale: locale))"
        guard let percentage else { return fraction }
        return "\(fraction) (\(VaultFormatters.reportPercentage(percentage, locale: locale)))"
    }

    private func append(
        _ value: String?,
        label: String,
        to fields: inout [VaultReportField]
    ) {
        guard let value else { return }
        fields.append(VaultReportField(label: label, value: value))
    }
}

nonisolated struct VaultReportField {
    let label: String
    let value: String
}
