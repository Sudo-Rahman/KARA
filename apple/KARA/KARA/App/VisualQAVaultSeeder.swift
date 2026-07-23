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
                filename: "Lingotin Or 50 g.png",
                mimeType: "image/png",
                data: UIImage(named: "AssetKindBarHero")?.pngData() ?? Data(),
                createdAt: date(daysAgo: 23, relativeTo: timestamp)
            ))
            context.insert(AssetAttachment(
                assetID: featuredAssetID,
                kind: .invoice,
                filename: "Facture Lingotin 50 g.txt",
                mimeType: "text/plain",
                pageCount: 1,
                data: Data(Self.invoiceText.utf8),
                createdAt: date(daysAgo: 22, relativeTo: timestamp)
            ))
            context.insert(AssetAttachment(
                assetID: featuredAssetID,
                kind: .certificate,
                filename: "Certificat d’authenticité.txt",
                mimeType: "text/plain",
                pageCount: 1,
                data: Data(Self.certificateText.utf8),
                createdAt: date(daysAgo: 21, relativeTo: timestamp)
            ))

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
                name: "Lingotin Or 50 g CPoR",
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
                storageLocationName: "Coffre principal",
                invoiceNumber: "FAC-2025-0918",
                serialNumber: "A982741",
                acquisitionMethod: .purchase,
                tags: ["Investissement", "Long terme"],
                createdAt: date(daysAgo: 22, relativeTo: timestamp),
                updatedAt: date(daysAgo: 22, relativeTo: timestamp)
            ),
            Asset(
                id: UUID(uuidString: "A1000000-0000-4000-8000-000000000002")!,
                name: "Pièce Napoléon 20 Francs",
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
                storageLocationName: "Coffre principal",
                acquisitionMethod: .purchase,
                tags: ["Historique", "Transmission"],
                createdAt: date(daysAgo: 15, relativeTo: timestamp),
                updatedAt: date(daysAgo: 15, relativeTo: timestamp)
            ),
            Asset(
                id: UUID(uuidString: "A1000000-0000-4000-8000-000000000003")!,
                name: "Maple Leaf 1 oz",
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
                storageLocationName: "Coffre principal",
                acquisitionMethod: .purchase,
                tags: ["Investissement"],
                createdAt: date(daysAgo: 9, relativeTo: timestamp),
                updatedAt: date(daysAgo: 9, relativeTo: timestamp)
            ),
            Asset(
                id: UUID(uuidString: "A1000000-0000-4000-8000-000000000004")!,
                name: "Bracelet Or 18 carats",
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
                storageLocationName: "Coffre secondaire",
                acquisitionMethod: .purchase,
                tags: ["Bijou", "Famille"],
                createdAt: date(daysAgo: 5, relativeTo: timestamp),
                updatedAt: date(daysAgo: 5, relativeTo: timestamp)
            ),
            Asset(
                id: UUID(uuidString: "A1000000-0000-4000-8000-000000000005")!,
                name: "Lingot Argent 1 kg",
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
                storageLocationName: "Coffre secondaire",
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

    private static let invoiceText = """
    KARA — FACTURE D’ACHAT

    Lingotin Or 50 g CPoR
    Pureté : 999,9 ‰
    Référence : KARA-QA-2026-0042
    Montant réglé : 3 950,00 EUR
    """

    private static let certificateText = """
    KARA — CERTIFICAT D’AUTHENTICITÉ

    Lingotin Or 50 g CPoR
    Métal : or fin
    Pureté : 999,9 ‰
    Numéro de série : A982741
    """
}
#endif
