#if DEBUG
import Foundation
import SwiftData
import UIKit

enum VisualQAVaultSeeder {
    static let launchArgument = "-KARASeedVault"

    static func seedIfRequested(
        in container: ModelContainer,
        arguments: [String]
    ) throws {
        guard arguments.contains(KaraModelContainerFactory.inMemoryLaunchArgument),
              arguments.contains(launchArgument)
        else {
            return
        }

        let context = container.mainContext
        guard try context.fetchCount(FetchDescriptor<Asset>()) == 0 else {
            return
        }

        let timestamp = Date()
        let assets = makeAssets(relativeTo: timestamp)

        do {
            assets.forEach(context.insert)

            let featuredAssetID = assets[0].id
            context.insert(AssetAttachment(
                assetID: featuredAssetID,
                kind: .objectPhoto,
                filename: localized(
                    french: "Lingotin Or 50 g.png",
                    english: "50 g Gold Bar.png"
                ),
                mimeType: "image/png",
                data: UIImage(named: "AssetKindBar")?.pngData() ?? Data(),
                createdAt: date(daysAgo: 23, relativeTo: timestamp)
            ))
            context.insert(AssetAttachment(
                assetID: featuredAssetID,
                kind: .invoice,
                filename: localized(
                    french: "Facture Lingotin 50 g.txt",
                    english: "50 g Gold Bar Invoice.txt"
                ),
                mimeType: "text/plain",
                pageCount: 1,
                data: Data(Self.invoiceText.utf8),
                createdAt: date(daysAgo: 22, relativeTo: timestamp)
            ))
            context.insert(AssetAttachment(
                assetID: featuredAssetID,
                kind: .certificate,
                filename: localized(
                    french: "Certificat d’authenticité.txt",
                    english: "Certificate of Authenticity.txt"
                ),
                mimeType: "text/plain",
                pageCount: 1,
                data: Data(Self.certificateText.utf8),
                createdAt: date(daysAgo: 21, relativeTo: timestamp)
            ))

            let recordedSale = try SalesLedger.record(
                asset: assets[1],
                quantity: 1,
                grossAmount: 690,
                feesAmount: 15,
                currencyCode: "EUR",
                soldAt: date(daysAgo: 31, relativeTo: timestamp),
                buyerName: "Comptoir Saint-Honoré",
                note: localized(
                    french: "Règlement reçu par virement",
                    english: "Payment received by bank transfer"
                ),
                existingSaleLines: [],
                alerts: [],
                createdAt: date(daysAgo: 31, relativeTo: timestamp)
            )
            context.insert(recordedSale.sale)
            context.insert(recordedSale.line)

            context.insert(try PriceAlert.make(
                assetID: assets[2].id,
                targetValue: 12_000,
                currentValue: 6_000,
                currencyCode: "EUR",
                createdAt: date(daysAgo: 3, relativeTo: timestamp)
            ))

            let reachedAlert = try PriceAlert.make(
                assetID: assets[0].id,
                targetValue: 7_000,
                currentValue: 6_000,
                currencyCode: "EUR",
                createdAt: date(daysAgo: 5, relativeTo: timestamp)
            )
            _ = reachedAlert.evaluate(
                currentValue: 7_000,
                at: date(daysAgo: 4, relativeTo: timestamp)
            )
            context.insert(reachedAlert)

            let cancelledAlert = try PriceAlert.make(
                assetID: assets[0].id,
                targetValue: 6_900,
                currentValue: 6_000,
                currencyCode: "EUR",
                createdAt: date(daysAgo: 7, relativeTo: timestamp)
            )
            cancelledAlert.cancel(at: date(daysAgo: 6, relativeTo: timestamp))
            context.insert(cancelledAlert)

            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func makeAssets(relativeTo timestamp: Date) -> [Asset] {
        [
            Asset(
                id: UUID(uuidString: "A1000000-0000-4000-8000-000000000001")!,
                name: localized(
                    french: "Lingotin Or 50 g CPoR",
                    english: "50 g CPoR Gold Bar"
                ),
                category: .bar,
                presetID: "bar-gold-50g",
                quantity: 1,
                purchaseDate: date(daysAgo: 310, relativeTo: timestamp),
                metal: .gold,
                weightGrams: 50,
                finenessPermille: 999.9,
                pricePaidMinorUnits: 395_000,
                currencyCode: "EUR",
                sellerName: "Comptoir des Métaux Précieux",
                storageLocationName: localized(
                    french: "Coffre principal",
                    english: "Main vault"
                ),
                invoiceNumber: "FAC-2025-0918",
                serialNumber: "A982741",
                acquisitionMethod: .purchase,
                tags: [
                    localized(french: "Investissement", english: "Investment"),
                    localized(french: "Long terme", english: "Long term"),
                ],
                createdAt: date(daysAgo: 22, relativeTo: timestamp),
                updatedAt: date(daysAgo: 22, relativeTo: timestamp)
            ),
            Asset(
                id: UUID(uuidString: "A1000000-0000-4000-8000-000000000002")!,
                name: localized(
                    french: "Pièce Napoléon 20 Francs",
                    english: "20 Franc Napoleon Coin"
                ),
                category: .coin,
                presetID: "coin-napoleon-20-francs",
                quantity: 4,
                purchaseDate: date(daysAgo: 235, relativeTo: timestamp),
                metal: .gold,
                weightGrams: 6.4516,
                finenessPermille: 900,
                pricePaidMinorUnits: 210_000,
                currencyCode: "EUR",
                sellerName: "Numis Collection",
                storageLocationName: localized(
                    french: "Coffre principal",
                    english: "Main vault"
                ),
                acquisitionMethod: .purchase,
                tags: [
                    localized(french: "Historique", english: "Historical"),
                    localized(french: "Transmission", english: "Legacy"),
                ],
                createdAt: date(daysAgo: 15, relativeTo: timestamp),
                updatedAt: date(daysAgo: 15, relativeTo: timestamp)
            ),
            Asset(
                id: UUID(uuidString: "A1000000-0000-4000-8000-000000000003")!,
                name: localized(
                    french: "Maple Leaf 1 oz",
                    english: "1 oz Maple Leaf"
                ),
                category: .coin,
                presetID: "coin-maple-leaf-1oz",
                quantity: 2,
                purchaseDate: date(daysAgo: 145, relativeTo: timestamp),
                metal: .gold,
                weightGrams: 31.1035,
                finenessPermille: 999.9,
                pricePaidMinorUnits: 465_000,
                currencyCode: "EUR",
                sellerName: "Maison Joubert",
                storageLocationName: localized(
                    french: "Coffre principal",
                    english: "Main vault"
                ),
                acquisitionMethod: .purchase,
                tags: [localized(french: "Investissement", english: "Investment")],
                createdAt: date(daysAgo: 9, relativeTo: timestamp),
                updatedAt: date(daysAgo: 9, relativeTo: timestamp)
            ),
            Asset(
                id: UUID(uuidString: "A1000000-0000-4000-8000-000000000004")!,
                name: localized(
                    french: "Bracelet Or 18 carats",
                    english: "18-Karat Gold Bracelet"
                ),
                category: .jewelry,
                quantity: 1,
                purchaseDate: date(daysAgo: 95, relativeTo: timestamp),
                metal: .gold,
                weightGrams: 12.6,
                metalKarat: 18,
                finenessPermille: 750,
                pricePaidMinorUnits: 72_000,
                currencyCode: "EUR",
                sellerName: "Maison Lémoine",
                storageLocationName: localized(
                    french: "Coffre secondaire",
                    english: "Secondary vault"
                ),
                acquisitionMethod: .purchase,
                tags: [
                    localized(french: "Bijou", english: "Jewellery"),
                    localized(french: "Famille", english: "Family"),
                ],
                createdAt: date(daysAgo: 5, relativeTo: timestamp),
                updatedAt: date(daysAgo: 5, relativeTo: timestamp)
            ),
            Asset(
                id: UUID(uuidString: "A1000000-0000-4000-8000-000000000005")!,
                name: localized(
                    french: "Lingot Argent 1 kg",
                    english: "1 kg Silver Bar"
                ),
                category: .bar,
                presetID: "bar-silver-1kg",
                quantity: 1,
                purchaseDate: date(daysAgo: 48, relativeTo: timestamp),
                metal: .silver,
                weightGrams: 1_000,
                finenessPermille: 999,
                pricePaidMinorUnits: 86_000,
                currencyCode: "EUR",
                sellerName: "Comptoir des Métaux Précieux",
                storageLocationName: localized(
                    french: "Coffre secondaire",
                    english: "Secondary vault"
                ),
                invoiceNumber: "FAC-2026-0611",
                serialNumber: "SIL-104729",
                acquisitionMethod: .purchase,
                tags: ["Diversification"],
                createdAt: date(daysAgo: 2, relativeTo: timestamp),
                updatedAt: date(daysAgo: 2, relativeTo: timestamp)
            ),
        ]
    }

    private static func date(daysAgo: Int, relativeTo timestamp: Date) -> Date {
        Calendar(identifier: .gregorian).date(
            byAdding: .day,
            value: -daysAgo,
            to: timestamp
        ) ?? timestamp
    }

    private static func localized(
        french: String,
        english: String
    ) -> String {
        Locale.current.language.languageCode?.identifier == "fr"
            ? french
            : english
    }

    private static var invoiceText: String {
        localized(
            french: """
            KARA — FACTURE D’ACHAT

            Lingotin Or 50 g CPoR
            Pureté : 999,9 ‰
            Référence : KARA-QA-2026-0042
            Montant réglé : 3 950,00 EUR
            """,
            english: """
            KARA — PURCHASE INVOICE

            50 g CPoR Gold Bar
            Purity: 999.9‰
            Reference: KARA-QA-2026-0042
            Amount paid: EUR 3,950.00
            """
        )
    }

    private static var certificateText: String {
        localized(
            french: """
            KARA — CERTIFICAT D’AUTHENTICITÉ

            Lingotin Or 50 g CPoR
            Métal : or fin
            Pureté : 999,9 ‰
            Numéro de série : A982741
            """,
            english: """
            KARA — CERTIFICATE OF AUTHENTICITY

            50 g CPoR Gold Bar
            Metal: fine gold
            Purity: 999.9‰
            Serial number: A982741
            """
        )
    }
}
#endif
