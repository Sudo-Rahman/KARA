#if DEBUG
import Foundation
import SwiftData
import UIKit

enum VisualQAVaultSeeder {
    nonisolated static let launchArgument = "-KARASeedVault"

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

            let invoice = try MediaDocumentFactory.invoicePDF(
                from: [documentImage(text: invoiceText)],
                filename: localized(
                    french: "Facture Lingotin 50 g.pdf",
                    english: "50 g Gold Bar Invoice.pdf"
                )
            )
            let certificateData = try MediaDocumentFactory.normalizedObjectJPEG(
                from: documentImage(text: certificateText)
            )

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
                filename: invoice.filename,
                mimeType: invoice.mimeType,
                pageCount: invoice.pageCount,
                data: invoice.data,
                createdAt: date(daysAgo: 22, relativeTo: timestamp)
            ))
            context.insert(AssetAttachment(
                assetID: featuredAssetID,
                kind: .certificate,
                filename: localized(
                    french: "Certificat d’authenticité.jpg",
                    english: "Certificate of Authenticity.jpg"
                ),
                mimeType: "image/jpeg",
                pageCount: 1,
                data: certificateData,
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

    private static func documentImage(text: String) -> UIImage {
        let bounds = CGRect(x: 0, y: 0, width: 1_240, height: 1_754)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard

        return UIGraphicsImageRenderer(bounds: bounds, format: format).image { context in
            UIColor(red: 0.98, green: 0.97, blue: 0.93, alpha: 1).setFill()
            context.fill(bounds)

            UIColor(red: 0.06, green: 0.16, blue: 0.33, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: bounds.width, height: 170))

            let paragraphs = text.components(separatedBy: "\n\n")
            let title = paragraphs.first ?? "KARA"
            let body = paragraphs.dropFirst().joined(separator: "\n\n")
            (title as NSString).draw(
                in: CGRect(x: 88, y: 54, width: bounds.width - 176, height: 80),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 42, weight: .bold),
                    .foregroundColor: UIColor.white,
                ]
            )
            (body as NSString).draw(
                in: CGRect(x: 88, y: 260, width: bounds.width - 176, height: bounds.height - 348),
                withAttributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 34, weight: .regular),
                    .foregroundColor: UIColor(red: 0.06, green: 0.16, blue: 0.33, alpha: 1),
                    .paragraphStyle: {
                        let style = NSMutableParagraphStyle()
                        style.lineSpacing = 14
                        return style
                    }(),
                ]
            )
        }
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

/// A deterministic, process-local market-data source used only by the explicit
/// visual-QA launch. Keeping both protocols in one value guarantees that this
/// path neither opens the disk cache nor constructs the attested network client.
nonisolated struct VisualQAMarketDataFixture: MarketDataCaching, MarketDataClient, Sendable {
    static let requiredLaunchArguments: Set<String> = [
        KaraModelContainerFactory.inMemoryLaunchArgument,
        VisualQAVaultSeeder.launchArgument,
        MarketDataStore.cachedOnlyLaunchArgument,
    ]

    static func isEnabled(arguments: [String]) -> Bool {
        requiredLaunchArguments.isSubset(of: Set(arguments))
    }

    static let timestamp = Date(timeIntervalSince1970: 1_785_844_800) // 2026-08-04 12:00 UTC
    static let dataVersion = "kara-visual-qa-2026-08"
    static let unit = MarketUnit(
        code: .troyOunce,
        grams: Decimal(string: "31.1034768")!
    )

    static let manifest = MarketManifest(
        schemaVersion: 1,
        datasetId: "precious-metals-monthly",
        dataVersion: dataVersion,
        publishedAt: timestamp,
        metals: MarketMetal.allCases,
        coverage: .init(from: "2025-09", through: "2026-08"),
        currencies: [
            MarketCurrency.eur.rawValue: .init(from: "2025-09", through: "2026-08"),
        ],
        file: .init(
            url: "/visual-qa/metals-monthly.json",
            sha256: String(repeating: "a", count: 64),
            bytes: 4_096
        )
    )

    static let bootstrap = MarketBootstrap(
        manifest: manifest,
        spots: [
            quote(metal: .gold, price: 3_050),
            quote(metal: .silver, price: Decimal(string: "35.10")!),
            quote(metal: .platinum, price: 1_180),
            quote(metal: .palladium, price: 1_140),
        ]
    )

    static let monthlyDataset = MonthlyDataset(
        unit: unit,
        series: [
            series(metal: .gold, prices: [
                2_450, 2_510, 2_485, 2_560, 2_620, 2_675,
                2_720, 2_790, 2_845, 2_910, 2_965, 3_020,
            ]),
            series(metal: .silver, prices: [
                28, 28.6, 29.1, 28.8, 29.7, 30.4,
                30.9, 31.6, 32.1, 32.8, 33.5, 34.4,
            ]),
            series(metal: .platinum, prices: [
                930, 945, 960, 975, 990, 1_015,
                1_035, 1_060, 1_085, 1_105, 1_130, 1_155,
            ]),
            series(metal: .palladium, prices: [
                900, 915, 940, 925, 955, 980,
                1_000, 1_025, 1_045, 1_070, 1_095, 1_120,
            ]),
        ]
    )

    func cachedBootstrap() async throws -> CachedMarketResource<MarketBootstrap>? {
        CachedMarketResource(value: Self.bootstrap, etag: Self.dataVersion, savedAt: Self.timestamp)
    }

    func saveBootstrap(_ entry: CachedMarketResource<MarketBootstrap>) async throws {}

    func cachedSpot(for pair: SpotPair) async throws -> CachedMarketResource<SpotQuote>? {
        guard let quote = Self.bootstrap.spots.first(where: { $0.id == pair }) else { return nil }
        return CachedMarketResource(value: quote, etag: Self.dataVersion, savedAt: Self.timestamp)
    }

    func saveSpot(
        _ entry: CachedMarketResource<SpotQuote>,
        for pair: SpotPair
    ) async throws {}

    func cachedMonthly() async throws -> CachedMonthlyResource? {
        CachedMonthlyResource(
            value: Self.monthlyDataset,
            etag: Self.dataVersion,
            dataVersion: Self.dataVersion,
            savedAt: Self.timestamp
        )
    }

    func saveMonthly(_ entry: CachedMonthlyResource) async throws {}

    func cachedManifest() async throws -> CachedMarketResource<MarketManifest>? {
        CachedMarketResource(value: Self.manifest, etag: Self.dataVersion, savedAt: Self.timestamp)
    }

    func saveManifest(_ entry: CachedMarketResource<MarketManifest>) async throws {}

    func bootstrap(etag: String?) async throws -> MarketFetchResult<MarketBootstrap> {
        .modified(Self.bootstrap, etag: Self.dataVersion)
    }

    func spot(
        for pair: SpotPair,
        etag: String?
    ) async throws -> MarketFetchResult<SpotQuote> {
        guard let quote = Self.bootstrap.spots.first(where: { $0.id == pair }) else {
            throw VisualQAMarketDataFixtureError.unsupportedPair(pair)
        }
        return .modified(quote, etag: Self.dataVersion)
    }

    func monthly(etag: String?) async throws -> MarketFetchResult<MonthlyDataset> {
        .modified(Self.monthlyDataset, etag: Self.dataVersion)
    }

    func manifest(etag: String?) async throws -> MarketFetchResult<MarketManifest> {
        .modified(Self.manifest, etag: Self.dataVersion)
    }

    private static func quote(metal: MarketMetal, price: Decimal) -> SpotQuote {
        SpotQuote(
            metal: metal,
            currency: .eur,
            price: price,
            unit: unit,
            sourceUpdatedAt: timestamp
        )
    }

    private static func series(metal: MarketMetal, prices: [Decimal]) -> MonthlySeries {
        let months = [
            "2025-09", "2025-10", "2025-11", "2025-12",
            "2026-01", "2026-02", "2026-03", "2026-04",
            "2026-05", "2026-06", "2026-07", "2026-08",
        ]
        return MonthlySeries(
            metal: metal,
            observations: zip(months, prices).map { month, price in
                MonthlyObservation(month: month, prices: [MarketCurrency.eur.rawValue: price])
            }
        )
    }
}

nonisolated enum VisualQAMarketDataFixtureError: Error, Equatable, Sendable {
    case unsupportedPair(SpotPair)
}
#endif
