import Foundation
import Testing
@testable import KARA

@Suite("KARA widget snapshot")
struct KaraWidgetSnapshotTests {
    @Test("The shared store round-trips precise market and portfolio values")
    func roundTripsPreciseSnapshot() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = KaraWidgetSnapshotStore(baseURL: directory)
        let snapshot = makeSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_785_000_000)
        )

        try store.write(snapshot)

        let loaded = try store.read()
        let decoded = try #require(loaded)
        #expect(decoded == snapshot)
        #expect(
            decoded.quotes.first?.pricePerGram
                == Decimal(string: "114.421323020711305174732105833261701469")!
        )
    }

    @Test("Snapshots reject unsupported schema versions")
    func rejectsUnsupportedSchema() {
        let snapshot = KaraWidgetSnapshot(
            schemaVersion: 2,
            generatedAt: Date(timeIntervalSince1970: 1_785_000_000),
            quotes: [],
            portfolio: nil,
            disclosure: .unavailable
        )

        #expect(
            throws: KaraWidgetSnapshotValidationError.unsupportedSchemaVersion(2)
        ) {
            try snapshot.validated()
        }
    }

    @Test("Snapshots reject duplicate quotes for one metal")
    func rejectsDuplicateMetals() {
        let quote = KaraWidgetQuote(
            metal: .silver,
            ouncePrice: 32,
            unitGrams: Decimal(string: "31.1034768")!,
            sourceUpdatedAt: Date(timeIntervalSince1970: 1_784_627_133)
        )
        let snapshot = KaraWidgetSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_785_000_000),
            quotes: [quote, quote],
            portfolio: nil,
            disclosure: .unavailable
        )

        #expect(
            throws: KaraWidgetSnapshotValidationError.duplicateQuote(.silver)
        ) {
            try snapshot.validated()
        }
    }

    @Test("Snapshots reject nonpositive or nonfinite quote values")
    func rejectsInvalidQuoteNumbers() {
        let date = Date(timeIntervalSince1970: 1_784_627_133)
        let invalidPrice = snapshot(
            quotes: [
                KaraWidgetQuote(
                    metal: .gold,
                    ouncePrice: 0,
                    unitGrams: Decimal(string: "31.1034768")!,
                    sourceUpdatedAt: date
                ),
            ]
        )
        let invalidUnit = snapshot(
            quotes: [
                KaraWidgetQuote(
                    metal: .palladium,
                    ouncePrice: 1_000,
                    unitGrams: .nan,
                    sourceUpdatedAt: date
                ),
            ]
        )

        #expect(
            throws: KaraWidgetSnapshotValidationError.invalidOuncePrice(.gold)
        ) {
            try invalidPrice.validated()
        }
        #expect(
            throws: KaraWidgetSnapshotValidationError.invalidUnitGrams(.palladium)
        ) {
            try invalidUnit.validated()
        }
    }

    @Test("Snapshots reject inconsistent portfolio coverage and history")
    func rejectsInvalidPortfolio() {
        let invalidCoverage = KaraWidgetPortfolio(
            totalValueEUR: 10,
            totalGainEUR: nil,
            gainPercentage: nil,
            valuedRecordCount: 2,
            totalRecordCount: 1,
            objectCount: 1,
            history: []
        )
        let duplicateDate = Date(timeIntervalSince1970: 1_775_000_000)
        let invalidHistory = KaraWidgetPortfolio(
            totalValueEUR: 10,
            totalGainEUR: nil,
            gainPercentage: nil,
            valuedRecordCount: 1,
            totalRecordCount: 1,
            objectCount: 1,
            history: [
                KaraWidgetHistoryPoint(date: duplicateDate, valueEUR: 8),
                KaraWidgetHistoryPoint(date: duplicateDate, valueEUR: 10),
            ]
        )

        #expect(
            throws: KaraWidgetSnapshotValidationError.invalidPortfolioCoverage
        ) {
            try snapshot(portfolio: invalidCoverage, disclosure: .visible).validated()
        }
        #expect(
            throws: KaraWidgetSnapshotValidationError.duplicateHistoryDate(duplicateDate)
        ) {
            try snapshot(portfolio: invalidHistory, disclosure: .visible).validated()
        }
    }

    @Test("Hidden and unavailable disclosures cannot retain portfolio values")
    func enforcesDisclosureDataMinimization() {
        let portfolio = KaraWidgetPortfolio(
            totalValueEUR: 10,
            totalGainEUR: nil,
            gainPercentage: nil,
            valuedRecordCount: 1,
            totalRecordCount: 1,
            objectCount: 1,
            history: []
        )

        #expect(
            throws: KaraWidgetSnapshotValidationError.inconsistentDisclosure(.hidden)
        ) {
            try snapshot(portfolio: portfolio, disclosure: .hidden).validated()
        }
        #expect(
            throws: KaraWidgetSnapshotValidationError.inconsistentDisclosure(.visible)
        ) {
            try snapshot(portfolio: nil, disclosure: .visible).validated()
        }
    }

    @Test("Reading a missing snapshot returns nil")
    func readsMissingSnapshotSafely() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = KaraWidgetSnapshotStore(baseURL: directory)

        #expect(try store.read() == nil)
        #expect(store.fileURL.path.hasSuffix("/Widget/v1/snapshot.json"))
    }

    @Test("Reading a corrupt snapshot reports a decoding error")
    func reportsCorruptSnapshot() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = KaraWidgetSnapshotStore(baseURL: directory)
        try FileManager.default.createDirectory(
            at: store.fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not-json".utf8).write(to: store.fileURL)

        #expect(throws: DecodingError.self) {
            try store.read()
        }
    }

    @Test("A new atomic write replaces the previous complete snapshot")
    func atomicallyReplacesSnapshot() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = KaraWidgetSnapshotStore(baseURL: directory)
        let first = snapshot(
            quotes: [
                KaraWidgetQuote(
                    metal: .gold,
                    ouncePrice: 3_500,
                    unitGrams: Decimal(string: "31.1034768")!,
                    sourceUpdatedAt: Date(timeIntervalSince1970: 1_784_627_100)
                ),
            ]
        )
        let replacement = snapshot(
            quotes: [
                KaraWidgetQuote(
                    metal: .silver,
                    ouncePrice: 35,
                    unitGrams: Decimal(string: "31.1034768")!,
                    sourceUpdatedAt: Date(timeIntervalSince1970: 1_784_627_200)
                ),
            ]
        )

        try store.write(first)
        try store.write(replacement)

        #expect(try store.read() == replacement)
        #expect(
            try FileManager.default.contentsOfDirectory(
                atPath: store.fileURL.deletingLastPathComponent().path
            ).count == 1
        )
    }

    @Test("Removing a snapshot leaves the widget fail-closed")
    func removesSnapshot() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = KaraWidgetSnapshotStore(baseURL: directory)

        try store.write(makeSnapshot(generatedAt: Date(timeIntervalSince1970: 1_785_000_000)))
        try store.remove()

        #expect(try store.read() == nil)
    }

    @Test("A rejected write preserves the last valid snapshot")
    func invalidWritePreservesSnapshot() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = KaraWidgetSnapshotStore(baseURL: directory)
        let valid = makeSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_785_000_000)
        )
        let invalid = KaraWidgetSnapshot(
            schemaVersion: 99,
            generatedAt: Date(timeIntervalSince1970: 1_785_000_100),
            quotes: [],
            portfolio: nil,
            disclosure: .unavailable
        )

        try store.write(valid)
        #expect(
            throws: KaraWidgetSnapshotValidationError.unsupportedSchemaVersion(99)
        ) {
            try store.write(invalid)
        }

        #expect(try store.read() == valid)
    }

    @Test("The persisted aggregate contains no personal asset fields")
    func excludesPersonalFields() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = KaraWidgetSnapshotStore(baseURL: directory)

        try store.write(makeSnapshot(generatedAt: Date(timeIntervalSince1970: 1_785_000_000)))

        let json = String(decoding: try Data(contentsOf: store.fileURL), as: UTF8.self)
        for forbiddenKey in [
            "assetID",
            "name",
            "seller",
            "storageLocation",
            "invoice",
            "serialNumber",
            "purchaseCost",
        ] {
            #expect(!json.contains("\"\(forbiddenKey)\""))
        }
    }

    @Test("Content comparison ignores only the publication timestamp")
    func comparesMaterialContent() {
        let first = makeSnapshot(generatedAt: Date(timeIntervalSince1970: 1_785_000_000))
        let republished = makeSnapshot(generatedAt: Date(timeIntervalSince1970: 1_785_000_100))
        let hidden = snapshot(disclosure: .hidden)

        #expect(first.hasSameContent(as: republished))
        #expect(!first.hasSameContent(as: hidden))
    }

    @Test("Publication freshness follows the oldest contributing quote")
    func publicationUsesQuoteSourceTimestamp() {
        let sourceDate = Date(timeIntervalSince1970: 1_700_000_000)
        let valuationDate = Date(timeIntervalSince1970: 1_800_000_000)
        let quote = SpotQuote(
            metal: .gold,
            currency: .eur,
            price: 3_500,
            unit: MarketUnit(code: .troyOunce, grams: Decimal(string: "31.1034768")!),
            sourceUpdatedAt: sourceDate
        )
        let valuation = PortfolioValuation(
            totalEstimatedValueEUR: 1_000,
            totalPurchaseCostEUR: nil,
            totalGainEUR: nil,
            gainPercentage: nil,
            assetValuations: [],
            metals: [],
            categories: [],
            coverage: PortfolioCoverage(
                totalRecordCount: 1,
                valuedRecordCount: 1,
                performanceRecordCount: 0,
                totalObjectCount: 1,
                valuedObjectCount: 1
            ),
            history: [],
            historyUsesUnknownPurchaseDates: false
        )

        let input = KaraWidgetSnapshotPublicationInput(
            quotes: [.gold: quote],
            valuation: valuation,
            valuationAsOf: valuationDate,
            hidesSensitiveValues: false
        )

        #expect(input.generatedAt == sourceDate)
    }

    private func makeSnapshot(generatedAt: Date) -> KaraWidgetSnapshot {
        KaraWidgetSnapshot(
            generatedAt: generatedAt,
            quotes: [
                KaraWidgetQuote(
                    metal: .gold,
                    ouncePrice: Decimal(string: "3558.900966")!,
                    unitGrams: Decimal(string: "31.1034768")!,
                    sourceUpdatedAt: Date(timeIntervalSince1970: 1_784_627_133)
                ),
            ],
            portfolio: KaraWidgetPortfolio(
                totalValueEUR: Decimal(string: "183421.23456789")!,
                totalGainEUR: Decimal(string: "21420.00000001")!,
                gainPercentage: Decimal(string: "13.223456789")!,
                valuedRecordCount: 4,
                totalRecordCount: 5,
                objectCount: 12,
                history: [
                    KaraWidgetHistoryPoint(
                        date: Date(timeIntervalSince1970: 1_775_000_000),
                        valueEUR: Decimal(string: "170000.12345678")!
                    ),
                    KaraWidgetHistoryPoint(
                        date: Date(timeIntervalSince1970: 1_784_627_133),
                        valueEUR: Decimal(string: "183421.23456789")!
                    ),
                ]
            ),
            disclosure: .visible
        )
    }

    private func snapshot(
        quotes: [KaraWidgetQuote] = [],
        portfolio: KaraWidgetPortfolio? = nil,
        disclosure: KaraWidgetDisclosure = .unavailable
    ) -> KaraWidgetSnapshot {
        KaraWidgetSnapshot(
            generatedAt: Date(timeIntervalSince1970: 1_785_000_000),
            quotes: quotes,
            portfolio: portfolio,
            disclosure: disclosure
        )
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appending(
                path: "KaraWidgetSnapshotTests-\(UUID().uuidString)",
                directoryHint: .isDirectory
            )
    }
}
