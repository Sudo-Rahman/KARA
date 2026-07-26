import Foundation
import PDFKit
import Testing
import UIKit
@testable import KARA

@Suite("Vault report")
@MainActor
struct VaultReportTests {
    @Test("The snapshot contains active assets and attachment metadata only")
    func snapshotContainsActiveAssetsOnly() async throws {
        let activeID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let deletedID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let active = Asset(
            id: activeID,
            name: "Montre Éclipse",
            quantity: 2,
            createdAt: date(2026, 7, 2)
        )
        let deleted = Asset(
            id: deletedID,
            name: "Actif supprimé",
            createdAt: date(2026, 7, 3),
            deletedAt: date(2026, 7, 4)
        )
        let attachment = AssetAttachment(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            assetID: activeID,
            kind: .invoice,
            filename: "Facture.pdf",
            mimeType: "application/pdf",
            pageCount: 3,
            data: Data(repeating: 0xAB, count: 64),
            createdAt: date(2026, 7, 5)
        )
        attachment.dataByteCount = nil
        let deletedAttachment = AssetAttachment(
            assetID: deletedID,
            filename: "deleted.jpg",
            data: Data([0x01])
        )

        let snapshot = VaultReportSnapshotAssembler.make(
            assets: [deleted, active],
            attachments: [deletedAttachment, attachment],
            valuation: emptyValuation(recordCount: 1, objectCount: 2),
            valuationAsOf: date(2026, 7, 6)
        )

        #expect(snapshot.assets.map(\.id) == [activeID])
        #expect(snapshot.recordCount == 1)
        #expect(snapshot.objectCount == 2)
        let copiedAttachment = try #require(snapshot.assets.first?.attachments.first)
        #expect(copiedAttachment.id == attachment.id)
        #expect(copiedAttachment.filename == "Facture.pdf")
        #expect(copiedAttachment.pageCount == 3)
        // An unknown historical byte count must stay unknown: deriving it from `data`
        // would prove the external-storage payload was read during report assembly.
        #expect(copiedAttachment.byteCount == nil)

        let cooperativeSnapshot = try await VaultReportSnapshotAssembler.makeCooperatively(
            assets: [deleted, active],
            attachments: [deletedAttachment, attachment],
            valuation: emptyValuation(recordCount: 1, objectCount: 2),
            valuationAsOf: date(2026, 7, 6)
        )
        #expect(cooperativeSnapshot == snapshot)
    }

    @Test("The snapshot preserves complete fields, valuations, costs, and deterministic order")
    func snapshotPreservesReportDataAndOrder() throws {
        let expectedPurchaseEUR = Decimal(string: "1234.56")!
        let expectedGainEUR = Decimal(string: "765.44")!
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
        let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000020")!
        let sameCreationDate = date(2026, 7, 20)
        let first = Asset(
            id: firstID,
            name: "Bague héritée 💍",
            category: .jewelry,
            presetID: "jewelry-custom",
            quantity: 3,
            purchaseDate: date(2020, 1, 2),
            metal: .gold,
            weightGrams: 12.5,
            metalKarat: 18,
            finenessPermille: 750,
            gemstoneCaratWeight: 1.25,
            gemstoneClarity: "VVS1",
            pricePaidMinorUnits: 123_456,
            currencyCode: "EUR",
            sellerName: "Maison André",
            storageLocationName: "Coffre n° 2",
            invoiceNumber: "FAC-É-42",
            serialNumber: "SÉRIE-01",
            acquisitionMethod: .inheritance,
            tags: ["famille", "assuré"],
            createdAt: sameCreationDate,
            updatedAt: date(2026, 7, 21)
        )
        let second = Asset(
            id: secondID,
            name: "Lingot secondaire",
            pricePaidMinorUnits: 5_000,
            currencyCode: "USD",
            createdAt: sameCreationDate
        )
        let attachmentDate = date(2026, 7, 22)
        let laterID = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
        let earlierID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
        let attachments = [
            AssetAttachment(
                id: laterID,
                assetID: firstID,
                kind: .certificate,
                filename: "z.pdf",
                pageCount: 2,
                createdAt: attachmentDate
            ),
            AssetAttachment(
                id: earlierID,
                assetID: firstID,
                kind: .objectPhoto,
                filename: "a.jpg",
                mimeType: "image/jpeg",
                createdAt: attachmentDate
            ),
        ]
        let firstValuation = makeAssetValuation(
            assetID: firstID,
            estimatedValueEUR: 2_000,
            gainEUR: expectedGainEUR,
            gainPercentage: 62
        )
        let valuation = makeValuation(
            assetValuations: [firstValuation],
            recordCount: 2,
            objectCount: 4,
            totalEstimatedValueEUR: 2_000,
            totalGainEUR: expectedGainEUR,
            gainPercentage: 62
        )

        let snapshot = VaultReportSnapshotAssembler.make(
            assets: [second, first],
            attachments: attachments,
            valuation: valuation,
            valuationAsOf: date(2026, 7, 23)
        )

        #expect(snapshot.assets.map(\.id) == [firstID, secondID])
        let copied = try #require(snapshot.assets.first)
        #expect(copied.name == "Bague héritée 💍")
        #expect(copied.preset?.localizationKey == "asset.preset.jewelry-custom")
        #expect(copied.purchaseDate == date(2020, 1, 2))
        #expect(copied.weightGrams == Decimal(string: "12.5"))
        #expect(copied.gemstoneCaratWeight == Decimal(string: "1.25"))
        #expect(copied.pricePaid == VaultReportMoney(
            amount: expectedPurchaseEUR,
            currencyCode: "EUR"
        ))
        #expect(copied.sellerName == "Maison André")
        #expect(copied.tags == ["famille", "assuré"])
        #expect(copied.valuation.estimatedValueEUR == 2_000)
        #expect(copied.valuation.gainEUR == expectedGainEUR)
        #expect(copied.attachments.map(\.id) == [earlierID, laterID])
        #expect(snapshot.purchaseCosts == [
            VaultReportPurchaseCost(currencyCode: "EUR", amount: expectedPurchaseEUR),
            VaultReportPurchaseCost(currencyCode: "USD", amount: 50),
        ])
        #expect(snapshot.valuation.coverage == valuation.coverage)
    }

    @Test("The suggested PDF filename uses the injected local calendar day")
    func suggestedFilenameIsStable() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        let generatedAt = Date(timeIntervalSince1970: 1_784_675_400)

        #expect(
            VaultReportTransfer.suggestedFilename(
                for: generatedAt,
                calendar: calendar
            ) == "Rapport-Coffre-KARA-2026-07-22.pdf"
        )
        #expect(
            VaultReportTransfer(
                data: Data([0x25, 0x50, 0x44, 0x46]),
                generatedAt: generatedAt,
                calendar: calendar
            ).filename == "Rapport-Coffre-KARA-2026-07-22.pdf"
        )
    }

    @Test("Purging reports removes a stale temporary report")
    func temporaryStorePurgesStaleReport() throws {
        let report = try TemporaryVaultReportFileStore.write(transfer: VaultReportTransfer(
            data: Data("first".utf8),
            generatedAt: date(2026, 7, 21)
        ))
        #expect(FileManager.default.fileExists(atPath: report.url.path))

        TemporaryVaultReportFileStore.purgeStaleReports()
        #expect(!FileManager.default.fileExists(atPath: report.url.path))
    }

    @Test("The renderer creates a localized, readable A4 PDF with report values")
    func rendererCreatesLocalizedPDF() throws {
        let expectedPurchaseEUR = Decimal(string: "1234.56")!
        let expectedGainEUR = Decimal(string: "1265.44")!
        let assetID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
        let asset = Asset(
            id: assetID,
            name: "Bague Héritage Émeraude",
            category: .jewelry,
            quantity: 1,
            purchaseDate: date(2022, 4, 3),
            metal: .gold,
            weightGrams: 8.75,
            metalKarat: 18,
            gemstoneCaratWeight: 1.2,
            gemstoneClarity: "VVS1",
            pricePaidMinorUnits: 123_456,
            currencyCode: "EUR",
            sellerName: "Maison André",
            storageLocationName: "Coffre principal",
            invoiceNumber: "FAC-É-2022",
            serialNumber: "SÉRIE-99",
            acquisitionMethod: .purchase,
            tags: ["famille", "assuré"],
            createdAt: date(2022, 4, 3),
            updatedAt: date(2026, 7, 21)
        )
        let attachment = AssetAttachment(
            assetID: assetID,
            kind: .invoice,
            filename: "Facture-Émeraude.pdf",
            mimeType: "application/pdf",
            pageCount: 2,
            data: Data(),
            createdAt: date(2022, 4, 3)
        )
        let valuation = makeValuation(
            assetValuations: [makeAssetValuation(
                assetID: assetID,
                estimatedValueEUR: 2_500,
                gainEUR: expectedGainEUR,
                gainPercentage: 102.5
            )],
            recordCount: 1,
            objectCount: 1,
            totalEstimatedValueEUR: 2_500,
            totalGainEUR: expectedGainEUR,
            gainPercentage: 102.5
        )
        let snapshot = VaultReportSnapshotAssembler.make(
            assets: [asset],
            attachments: [attachment],
            valuation: valuation,
            valuationAsOf: date(2026, 7, 22, 15)
        )

        let data = try VaultReportPDFRenderer(
            snapshot: snapshot,
            locale: Locale(identifier: "fr_FR"),
            generatedAt: date(2026, 7, 22, 16)
        ).render()
        let document = try #require(PDFDocument(data: data))
        let text = normalizedPDFText(document)
        let firstPageBounds = try #require(document.page(at: 0)?.bounds(for: .mediaBox))

        #expect(document.pageCount >= 2)
        #expect(abs(firstPageBounds.width - 595.28) < 0.2)
        #expect(abs(firstPageBounds.height - 841.89) < 0.2)
        #expect(text.contains("Rapport complet du coffre"))
        #expect(text.contains("Synthèse du coffre"))
        #expect(text.contains("Bague Héritage Émeraude"))
        #expect(text.contains("Facture-Émeraude.pdf"))
        #expect(text.contains("VVS1"))
        #expect(text.contains(normalizedWhitespace(
            VaultFormatters.reportCurrency(
                expectedPurchaseEUR,
                code: "EUR",
                locale: Locale(identifier: "fr_FR")
            )
        )))
    }

    @Test("A summary without any valued asset does not present zero as a valuation")
    func rendererMarksMissingValuationUnavailable() throws {
        let asset = Asset(name: "Not valued", createdAt: date(2026, 7, 20))
        let snapshot = VaultReportSnapshotAssembler.make(
            assets: [asset],
            attachments: [],
            valuation: emptyValuation(recordCount: 1, objectCount: 1),
            valuationAsOf: date(2026, 7, 22)
        )
        let locale = Locale(identifier: "en_US")
        let data = try VaultReportPDFRenderer(
            snapshot: snapshot,
            locale: locale,
            generatedAt: date(2026, 7, 22)
        ).render()
        let document = try #require(PDFDocument(data: data))
        let text = normalizedPDFText(document)
        let zeroValue = normalizedWhitespace(VaultFormatters.reportCurrency(
            0,
            code: "EUR",
            locale: locale
        ))

        #expect(text.contains("Not available"))
        #expect(!text.contains(zeroValue))
    }

    @Test("A standard detailed asset fits on one A4 detail page")
    func rendererKeepsStandardDetailedAssetOnOnePage() throws {
        let asset = Asset(
            name: "Bracelet Or 18 carats",
            category: .jewelry,
            quantity: 1,
            purchaseDate: date(2026, 4, 22),
            metal: .gold,
            weightGrams: 12.6,
            metalKarat: 18,
            finenessPermille: 750,
            pricePaidMinorUnits: 72_000,
            currencyCode: "EUR",
            sellerName: "Maison L\u{00E9}moine",
            storageLocationName: "Coffre secondaire",
            acquisitionMethod: .purchase,
            tags: ["Bijou", "Famille"],
            createdAt: date(2026, 7, 21),
            updatedAt: date(2026, 7, 21)
        )
        let gainEUR = Decimal(string: "364.51")!
        let snapshot = VaultReportSnapshotAssembler.make(
            assets: [asset],
            attachments: [],
            valuation: makeValuation(
                assetValuations: [makeAssetValuation(
                    assetID: asset.id,
                    estimatedValueEUR: Decimal(string: "1084.51")!,
                    gainEUR: gainEUR,
                    gainPercentage: Decimal(string: "50.6")!
                )],
                recordCount: 1,
                objectCount: 1,
                totalEstimatedValueEUR: Decimal(string: "1084.51")!,
                totalGainEUR: gainEUR,
                gainPercentage: Decimal(string: "50.6")!
            ),
            valuationAsOf: date(2026, 7, 26)
        )

        let data = try VaultReportPDFRenderer(
            snapshot: snapshot,
            locale: Locale(identifier: "fr_FR"),
            generatedAt: date(2026, 7, 26)
        ).render()
        let document = try #require(PDFDocument(data: data))

        #expect(document.pageCount == 2)
    }

    @Test("A rich asset with three attachments avoids a single-field continuation")
    func rendererAvoidsSingleFieldAttachmentContinuation() throws {
        let assetID = UUID(uuidString: "A1000000-0000-4000-8000-000000000001")!
        let asset = Asset(
            id: assetID,
            name: "Lingotin Or 50 g CPoR",
            category: .bar,
            quantity: 1,
            purchaseDate: date(2025, 9, 19),
            metal: .gold,
            weightGrams: 50,
            finenessPermille: 999.9,
            pricePaidMinorUnits: 395_000,
            currencyCode: "EUR",
            sellerName: "Comptoir des Métaux Précieux",
            storageLocationName: "Coffre principal",
            invoiceNumber: "FAC-2025-0918",
            serialNumber: "A982741",
            acquisitionMethod: .purchase,
            tags: ["Investissement", "Long terme"],
            createdAt: date(2026, 7, 4),
            updatedAt: date(2026, 7, 4)
        )
        let attachments = [
            AssetAttachment(
                assetID: assetID,
                kind: .objectPhoto,
                filename: "Lingotin Or 50 g.png",
                mimeType: "image/png",
                data: Data(repeating: 0xAB, count: 1_500_000),
                createdAt: date(2026, 7, 3)
            ),
            AssetAttachment(
                assetID: assetID,
                kind: .invoice,
                filename: "Facture Lingotin 50 g.txt",
                mimeType: "text/plain",
                pageCount: 1,
                data: Data(repeating: 0xAB, count: 132),
                createdAt: date(2026, 7, 4)
            ),
            AssetAttachment(
                assetID: assetID,
                kind: .certificate,
                filename: "Certificat d’authenticité.txt",
                mimeType: "text/plain",
                pageCount: 1,
                data: Data(repeating: 0xAB, count: 124),
                createdAt: date(2026, 7, 5)
            ),
        ]
        let gainEUR = Decimal(string: "1787.58")!
        let snapshot = VaultReportSnapshotAssembler.make(
            assets: [asset],
            attachments: attachments,
            valuation: makeValuation(
                assetValuations: [makeAssetValuation(
                    assetID: assetID,
                    estimatedValueEUR: Decimal(string: "5737.58")!,
                    gainEUR: gainEUR,
                    gainPercentage: Decimal(string: "45.3")!
                )],
                recordCount: 1,
                objectCount: 1,
                totalEstimatedValueEUR: Decimal(string: "5737.58")!,
                totalGainEUR: gainEUR,
                gainPercentage: Decimal(string: "45.3")!
            ),
            valuationAsOf: date(2026, 7, 26)
        )

        let data = try VaultReportPDFRenderer(
            snapshot: snapshot,
            locale: Locale(identifier: "fr_FR"),
            generatedAt: date(2026, 7, 26)
        ).render()
        let document = try #require(PDFDocument(data: data))
        let lastPageText = try #require(document.page(at: 2)?.string)

        #expect(document.pageCount == 3)
        #expect(lastPageText.contains(asset.name))
        #expect(lastPageText.contains("Lingotin Or 50 g.png"))
        #expect(lastPageText.contains("Ajouté le"))
    }

    @Test("A field taller than a titled continuation page flows without recursion")
    func rendererFlowsMediumLongFieldAcrossTitledContinuation() throws {
        let repeatedWord = "Éléphant"
        let valueFont = UIFont.systemFont(ofSize: 11.5, weight: .regular)
        let contentWidth = VaultReportPDFLayout.pageSize.width
            - 2 * VaultReportPDFLayout.horizontalMargin
        var words: [String] = []
        var valueHeight: CGFloat = 0

        while valueHeight < 655 {
            words.append(repeatedWord)
            let value = words.joined(separator: " ")
            valueHeight = ceil((value as NSString).boundingRect(
                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: valueFont],
                context: nil
            ).height)
        }

        let asset = Asset(
            name: "Champ sur plusieurs pages",
            sellerName: words.joined(separator: " "),
            createdAt: date(2026, 7, 20)
        )
        let snapshot = VaultReportSnapshotAssembler.make(
            assets: [asset],
            attachments: [],
            valuation: emptyValuation(recordCount: 1, objectCount: 1),
            valuationAsOf: date(2026, 7, 22)
        )

        let data = try VaultReportPDFRenderer(
            snapshot: snapshot,
            locale: Locale(identifier: "fr_FR"),
            generatedAt: date(2026, 7, 22)
        ).render()
        let document = try #require(PDFDocument(data: data))
        let text = normalizedPDFText(document)

        #expect(document.pageCount == 3)
        #expect(text.components(separatedBy: repeatedWord).count - 1 == words.count)
    }

    @Test("Long Unicode fields continue on new pages without losing content")
    func rendererPaginatesLongUnicodeFields() throws {
        let repeatedWord = "Éléphant"
        let longSeller = Array(repeating: repeatedWord, count: 700).joined(separator: " ")
        let asset = Asset(
            name: "Texte très long",
            sellerName: longSeller,
            createdAt: date(2026, 7, 20)
        )
        let gainEUR = Decimal(string: "1265.44")!
        let snapshot = VaultReportSnapshotAssembler.make(
            assets: [asset],
            attachments: [],
            valuation: makeValuation(
                assetValuations: [makeAssetValuation(
                    assetID: asset.id,
                    estimatedValueEUR: 2_500,
                    gainEUR: gainEUR,
                    gainPercentage: 102.5
                )],
                recordCount: 1,
                objectCount: 1,
                totalEstimatedValueEUR: 2_500,
                totalGainEUR: gainEUR,
                gainPercentage: 102.5
            ),
            valuationAsOf: date(2026, 7, 22)
        )

        let data = try VaultReportPDFRenderer(
            snapshot: snapshot,
            locale: Locale(identifier: "en_US"),
            generatedAt: date(2026, 7, 22)
        ).render()
        let document = try #require(PDFDocument(data: data))
        let text = normalizedPDFText(document)
        let formattedGain = normalizedWhitespace(VaultFormatters.reportCurrency(
            gainEUR,
            code: "EUR",
            locale: Locale(identifier: "en_US"),
            showsPositiveSign: true
        ))

        #expect(document.pageCount > 2)
        #expect(text.contains("Complete vault report"))
        #expect(formattedGain.contains("€"))
        #expect(text.contains(formattedGain))
        #expect(text.components(separatedBy: repeatedWord).count - 1 == 700)
        for pageIndex in 2..<document.pageCount {
            let pageText = try #require(document.page(at: pageIndex)?.string)
            #expect(pageText.contains("Texte très long"))
        }
    }
}

private func emptyValuation(recordCount: Int, objectCount: Int) -> PortfolioValuation {
    makeValuation(
        assetValuations: [],
        recordCount: recordCount,
        objectCount: objectCount
    )
}

private func makeValuation(
    assetValuations: [AssetValuation],
    recordCount: Int,
    objectCount: Int,
    totalEstimatedValueEUR: Decimal = 0,
    totalGainEUR: Decimal? = nil,
    gainPercentage: Decimal? = nil
) -> PortfolioValuation {
    let valuedRecordCount = assetValuations.count(where: {
        $0.estimatedValueEUR != nil
    })
    let performanceRecordCount = assetValuations.count(where: {
        $0.gainEUR != nil
    })
    return PortfolioValuation(
        totalEstimatedValueEUR: totalEstimatedValueEUR,
        totalPurchaseCostEUR: nil,
        totalGainEUR: totalGainEUR,
        gainPercentage: gainPercentage,
        assetValuations: assetValuations,
        metals: [],
        categories: [],
        coverage: PortfolioCoverage(
            totalRecordCount: recordCount,
            valuedRecordCount: valuedRecordCount,
            performanceRecordCount: performanceRecordCount,
            totalObjectCount: objectCount,
            valuedObjectCount: valuedRecordCount
        ),
        history: [],
        historyUsesUnknownPurchaseDates: false
    )
}

private func makeAssetValuation(
    assetID: UUID,
    estimatedValueEUR: Decimal?,
    gainEUR: Decimal?,
    gainPercentage: Decimal?
) -> AssetValuation {
    AssetValuation(
        assetID: assetID,
        name: "Asset",
        categoryID: AssetCategory.custom.rawValue,
        metal: nil,
        quantity: 1,
        fineWeightGrams: nil,
        estimatedValueEUR: estimatedValueEUR,
        purchaseCost: nil,
        purchaseCurrency: nil,
        currentValueInPurchaseCurrency: nil,
        purchaseCostEUR: nil,
        gainInPurchaseCurrency: nil,
        gainEUR: gainEUR,
        gainPercentage: gainPercentage,
        status: estimatedValueEUR == nil ? .missingMetal : .valued
    )
}

private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar.date(from: DateComponents(
        year: year,
        month: month,
        day: day,
        hour: hour
    ))!
}

private func documentText(_ document: PDFDocument) -> String {
    (0..<document.pageCount)
        .compactMap { document.page(at: $0)?.string }
        .joined(separator: "\n")
}

private func normalizedPDFText(_ document: PDFDocument) -> String {
    normalizedWhitespace(documentText(document))
}

private func normalizedWhitespace(_ value: String) -> String {
    value
        .replacingOccurrences(of: "\u{00A0}", with: " ")
        .replacingOccurrences(of: "\u{202F}", with: " ")
}
