import Foundation
import Testing
@testable import KARA

@Suite("Transaction-aware portfolio history")
struct PortfolioHoldingHistoryTests {
    @Test("Monthly history keeps the pre-sale quantity and applies the sale from its date")
    func appliesSalesAtTheirEffectiveDate() throws {
        let assetID = UUID()
        let asset = PortfolioAssetSnapshot(
            id: assetID,
            name: "Two coins",
            categoryID: AssetCategory.coin.rawValue,
            metal: .gold,
            quantity: 2,
            grossWeightGrams: 10,
            finenessPermille: 1_000,
            purchaseDate: date(2026, 1, 5)
        )
        let monthly = MonthlyDataset(
            unit: MarketUnit(code: .troyOunce, grams: 1),
            series: [
                MonthlySeries(
                    metal: .gold,
                    observations: [
                        MonthlyObservation(month: "2026-02", prices: ["EUR": 5]),
                        MonthlyObservation(month: "2026-03", prices: ["EUR": 6]),
                    ]
                ),
            ]
        )
        let market = PortfolioMarketSnapshot(
            currentQuotes: [
                SpotQuote(
                    metal: .gold,
                    currency: .eur,
                    price: 7,
                    unit: MarketUnit(code: .troyOunce, grams: 1),
                    sourceUpdatedAt: date(2026, 4, 15)
                ),
            ],
            monthly: monthly
        )

        let history = PortfolioHoldingHistoryEngine().history(
            assets: [asset],
            sales: [
                PortfolioQuantityEvent(
                    assetID: assetID,
                    occurredAt: date(2026, 3, 10),
                    quantity: 1
                ),
            ],
            market: market,
            asOf: date(2026, 4, 15),
            calendar: utcCalendar
        )

        #expect(history.map(\.valueEUR) == [100, 60, 70])
        #expect(history.map(\.totalHeldRecordCount) == [1, 1, 1])
        #expect(history.last?.isCurrent == true)
    }

    @Test("A complete sale ends the line at zero instead of rewriting past values")
    func preservesHistoryAfterLiquidation() {
        let assetID = UUID()
        let asset = PortfolioAssetSnapshot(
            id: assetID,
            name: "Sold coin",
            categoryID: AssetCategory.coin.rawValue,
            metal: .gold,
            quantity: 1,
            grossWeightGrams: 10,
            finenessPermille: 1_000,
            purchaseDate: date(2026, 1, 5)
        )
        let monthly = MonthlyDataset(
            unit: MarketUnit(code: .troyOunce, grams: 1),
            series: [
                MonthlySeries(
                    metal: .gold,
                    observations: [
                        MonthlyObservation(month: "2026-02", prices: ["EUR": 5]),
                        MonthlyObservation(month: "2026-03", prices: ["EUR": 6]),
                    ]
                ),
            ]
        )

        let history = PortfolioHoldingHistoryEngine().history(
            assets: [asset],
            saleEvents: [
                PortfolioSaleHistoryEvent(
                    occurredAt: date(2026, 3, 10),
                    soldQuantity: 1,
                    assetSnapshotBeforeSale: asset
                ),
            ],
            market: PortfolioMarketSnapshot(currentQuotes: [], monthly: monthly),
            asOf: date(2026, 4, 15),
            calendar: utcCalendar
        )

        #expect(history.first?.valueEUR == 50)
        #expect(history.last?.valueEUR == 0)
        #expect(history.last?.totalHeldRecordCount == 0)
        #expect(history.last?.isCurrent == true)
    }

    @Test("Editing an asset after a sale does not rewrite its pre-sale valuation")
    func saleSnapshotProtectsEarlierHistoryFromLaterEdits() {
        let assetID = UUID()
        let currentAsset = PortfolioAssetSnapshot(
            id: assetID,
            name: "Edited holding",
            categoryID: AssetCategory.coin.rawValue,
            metal: .gold,
            quantity: 4,
            grossWeightGrams: 20,
            finenessPermille: 500,
            purchaseDate: date(2026, 1, 5)
        )
        let assetAtSale = PortfolioAssetSnapshot(
            id: assetID,
            name: "Original holding",
            categoryID: AssetCategory.coin.rawValue,
            metal: .gold,
            quantity: 2,
            grossWeightGrams: 10,
            finenessPermille: 1_000,
            purchaseDate: date(2026, 1, 5)
        )
        let market = PortfolioMarketSnapshot(
            currentQuotes: [
                SpotQuote(
                    metal: .gold,
                    currency: .eur,
                    price: 7,
                    unit: MarketUnit(code: .troyOunce, grams: 1),
                    sourceUpdatedAt: date(2026, 4, 15)
                ),
            ],
            monthly: MonthlyDataset(
                unit: MarketUnit(code: .troyOunce, grams: 1),
                series: [
                    MonthlySeries(
                        metal: .gold,
                        observations: [
                            MonthlyObservation(
                                month: "2026-02",
                                prices: ["EUR": 5]
                            ),
                            MonthlyObservation(
                                month: "2026-03",
                                prices: ["EUR": 6]
                            ),
                        ]
                    ),
                ]
            )
        )

        let history = PortfolioHoldingHistoryEngine().history(
            assets: [currentAsset],
            saleEvents: [
                PortfolioSaleHistoryEvent(
                    occurredAt: date(2026, 3, 10),
                    soldQuantity: 1,
                    assetSnapshotBeforeSale: assetAtSale
                ),
            ],
            market: market,
            asOf: date(2026, 4, 15),
            calendar: utcCalendar
        )

        #expect(history.map(\.valueEUR) == [100, 180, 210])
        #expect(history.map(\.valuedRecordCount) == [1, 1, 1])
    }

    @Test("Each interval uses the next sale's immutable asset version")
    func twoSalesPreserveTheVersionHeldBetweenThem() {
        let assetID = UUID()
        let firstLineID = UUID()
        let secondLineID = UUID()
        let currentAsset = PortfolioAssetSnapshot(
            id: assetID,
            name: "Current version",
            categoryID: AssetCategory.coin.rawValue,
            metal: .gold,
            quantity: 4,
            grossWeightGrams: 30,
            finenessPermille: 1_000,
            purchaseDate: date(2026, 1, 5)
        )
        let firstSaleVersion = PortfolioAssetSnapshot(
            id: assetID,
            name: "First version",
            categoryID: AssetCategory.coin.rawValue,
            metal: .gold,
            quantity: 3,
            grossWeightGrams: 10,
            finenessPermille: 1_000,
            purchaseDate: date(2026, 1, 5)
        )
        let secondSaleVersion = PortfolioAssetSnapshot(
            id: assetID,
            name: "Second version",
            categoryID: AssetCategory.coin.rawValue,
            metal: .gold,
            quantity: 3,
            grossWeightGrams: 20,
            finenessPermille: 500,
            purchaseDate: date(2026, 1, 5)
        )
        let market = PortfolioMarketSnapshot(
            currentQuotes: [
                SpotQuote(
                    metal: .gold,
                    currency: .eur,
                    price: 1,
                    unit: MarketUnit(code: .troyOunce, grams: 1),
                    sourceUpdatedAt: date(2026, 7, 15)
                ),
            ],
            monthly: MonthlyDataset(
                unit: MarketUnit(code: .troyOunce, grams: 1),
                series: [
                    MonthlySeries(
                        metal: .gold,
                        observations: [
                            MonthlyObservation(
                                month: "2026-02",
                                prices: ["EUR": 1]
                            ),
                            MonthlyObservation(
                                month: "2026-04",
                                prices: ["EUR": 1]
                            ),
                            MonthlyObservation(
                                month: "2026-06",
                                prices: ["EUR": 1]
                            ),
                        ]
                    ),
                ]
            )
        )

        let history = PortfolioHoldingHistoryEngine().history(
            assets: [currentAsset],
            saleEvents: [
                PortfolioSaleHistoryEvent(
                    id: secondLineID,
                    occurredAt: date(2026, 5, 10),
                    soldQuantity: 1,
                    assetSnapshotBeforeSale: secondSaleVersion
                ),
                PortfolioSaleHistoryEvent(
                    id: firstLineID,
                    occurredAt: date(2026, 3, 10),
                    soldQuantity: 1,
                    assetSnapshotBeforeSale: firstSaleVersion
                ),
            ],
            market: market,
            asOf: date(2026, 7, 15),
            calendar: utcCalendar
        )

        #expect(history.map(\.valueEUR) == [30, 20, 60, 60])
    }

    @Test("A voided sale omitted by the caller has no effect on history")
    func callerProvidesOnlyActiveSaleEvents() {
        let assetID = UUID()
        let asset = PortfolioAssetSnapshot(
            id: assetID,
            name: "Three coins",
            categoryID: AssetCategory.coin.rawValue,
            metal: .gold,
            quantity: 3,
            grossWeightGrams: 10,
            finenessPermille: 1_000,
            purchaseDate: date(2026, 1, 5)
        )
        let sourceEvents = [
            (
                isActive: true,
                event: PortfolioSaleHistoryEvent(
                    occurredAt: date(2026, 3, 10),
                    soldQuantity: 1,
                    assetSnapshotBeforeSale: asset
                )
            ),
            (
                isActive: false,
                event: PortfolioSaleHistoryEvent(
                    occurredAt: date(2026, 4, 10),
                    soldQuantity: 1,
                    assetSnapshotBeforeSale: asset
                )
            ),
        ]
        let activeSaleEvents = sourceEvents
            .filter { $0.isActive }
            .map { $0.event }
        let market = PortfolioMarketSnapshot(
            currentQuotes: [
                SpotQuote(
                    metal: .gold,
                    currency: .eur,
                    price: 1,
                    unit: MarketUnit(code: .troyOunce, grams: 1),
                    sourceUpdatedAt: date(2026, 6, 15)
                ),
            ],
            monthly: MonthlyDataset(
                unit: MarketUnit(code: .troyOunce, grams: 1),
                series: [
                    MonthlySeries(
                        metal: .gold,
                        observations: [
                            MonthlyObservation(
                                month: "2026-02",
                                prices: ["EUR": 1]
                            ),
                            MonthlyObservation(
                                month: "2026-05",
                                prices: ["EUR": 1]
                            ),
                        ]
                    ),
                ]
            )
        )

        let history = PortfolioHoldingHistoryEngine().history(
            assets: [asset],
            saleEvents: activeSaleEvents,
            market: market,
            asOf: date(2026, 6, 15),
            calendar: utcCalendar
        )

        #expect(history.map(\.valueEUR) == [30, 20, 20])
    }

    @Test("Duplicate, invalid, and future sale events cannot reduce holdings")
    func sanitizesSaleEventQuantitiesAndIdentity() {
        let assetID = UUID()
        let asset = PortfolioAssetSnapshot(
            id: assetID,
            name: "Three coins",
            categoryID: AssetCategory.coin.rawValue,
            metal: .gold,
            quantity: 3,
            grossWeightGrams: 10,
            finenessPermille: 1_000,
            purchaseDate: date(2026, 1, 5)
        )
        let activeEvent = PortfolioSaleHistoryEvent(
            id: UUID(),
            occurredAt: date(2026, 3, 10),
            soldQuantity: 1,
            assetSnapshotBeforeSale: asset
        )
        let futureVersion = PortfolioAssetSnapshot(
            id: assetID,
            name: "Future edit",
            categoryID: AssetCategory.coin.rawValue,
            metal: .gold,
            quantity: 9,
            grossWeightGrams: 99,
            finenessPermille: 1_000,
            purchaseDate: date(2026, 1, 5)
        )
        let market = PortfolioMarketSnapshot(
            currentQuotes: [
                SpotQuote(
                    metal: .gold,
                    currency: .eur,
                    price: 1,
                    unit: MarketUnit(code: .troyOunce, grams: 1),
                    sourceUpdatedAt: date(2026, 4, 15)
                ),
            ],
            monthly: MonthlyDataset(
                unit: MarketUnit(code: .troyOunce, grams: 1),
                series: [
                    MonthlySeries(
                        metal: .gold,
                        observations: [
                            MonthlyObservation(
                                month: "2026-02",
                                prices: ["EUR": 1]
                            ),
                            MonthlyObservation(
                                month: "2026-03",
                                prices: ["EUR": 1]
                            ),
                        ]
                    ),
                ]
            )
        )

        let history = PortfolioHoldingHistoryEngine().history(
            assets: [asset],
            saleEvents: [
                activeEvent,
                activeEvent,
                PortfolioSaleHistoryEvent(
                    occurredAt: date(2026, 3, 11),
                    soldQuantity: 0,
                    assetSnapshotBeforeSale: asset
                ),
                PortfolioSaleHistoryEvent(
                    occurredAt: date(2026, 3, 12),
                    soldQuantity: -2,
                    assetSnapshotBeforeSale: asset
                ),
                PortfolioSaleHistoryEvent(
                    occurredAt: date(2026, 3, 13),
                    soldQuantity: 4,
                    assetSnapshotBeforeSale: asset
                ),
                PortfolioSaleHistoryEvent(
                    occurredAt: date(2026, 5, 10),
                    soldQuantity: 1,
                    assetSnapshotBeforeSale: futureVersion
                ),
            ],
            market: market,
            asOf: date(2026, 4, 15),
            calendar: utcCalendar
        )

        #expect(history.map(\.valueEUR) == [30, 20, 20])
    }

    @Test("Missing data in an immutable sale snapshot stays explicit")
    func preservesIncompleteHistoricalCoverage() {
        let assetID = UUID()
        let currentAsset = PortfolioAssetSnapshot(
            id: assetID,
            name: "Completed later",
            categoryID: AssetCategory.coin.rawValue,
            metal: .gold,
            quantity: 2,
            grossWeightGrams: 10,
            finenessPermille: 1_000,
            purchaseDate: date(2026, 1, 5)
        )
        let incompleteSaleVersion = PortfolioAssetSnapshot(
            id: assetID,
            name: "Incomplete at sale",
            categoryID: AssetCategory.coin.rawValue,
            metal: .gold,
            quantity: 2,
            grossWeightGrams: nil,
            finenessPermille: 1_000,
            purchaseDate: date(2026, 1, 5)
        )
        let market = PortfolioMarketSnapshot(
            currentQuotes: [
                SpotQuote(
                    metal: .gold,
                    currency: .eur,
                    price: 1,
                    unit: MarketUnit(code: .troyOunce, grams: 1),
                    sourceUpdatedAt: date(2026, 4, 15)
                ),
            ],
            monthly: MonthlyDataset(
                unit: MarketUnit(code: .troyOunce, grams: 1),
                series: [
                    MonthlySeries(
                        metal: .gold,
                        observations: [
                            MonthlyObservation(
                                month: "2026-02",
                                prices: ["EUR": 1]
                            ),
                            MonthlyObservation(
                                month: "2026-03",
                                prices: ["EUR": 1]
                            ),
                        ]
                    ),
                ]
            )
        )

        let history = PortfolioHoldingHistoryEngine().history(
            assets: [currentAsset],
            saleEvents: [
                PortfolioSaleHistoryEvent(
                    occurredAt: date(2026, 3, 10),
                    soldQuantity: 1,
                    assetSnapshotBeforeSale: incompleteSaleVersion
                ),
            ],
            market: market,
            asOf: date(2026, 4, 15),
            calendar: utcCalendar
        )

        #expect(history.first?.valueEUR == 0)
        #expect(history.first?.totalHeldRecordCount == 1)
        #expect(history.first?.valuedRecordCount == 0)
        #expect(history.dropFirst().allSatisfy {
            $0.totalHeldRecordCount == 1 && $0.valuedRecordCount == 1
        })
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utcCalendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: 12
        ))!
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
