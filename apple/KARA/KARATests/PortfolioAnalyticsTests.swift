import Foundation
import Testing
@testable import KARA

@Suite("Portfolio analytics")
struct PortfolioAnalyticsTests {
    @Test("Sales count uses natural singular and plural copy")
    func salesCountCopyUsesNaturalGrammar() {
        #expect(
            AnalysisSalesCountCopy.localizationKey(for: 1)
                == "analysis.sales.count.one"
        )
        #expect(
            AnalysisSalesCountCopy.localizationKey(for: 0)
                == "analysis.sales.count.other"
        )
        #expect(
            AnalysisSalesCountCopy.localizationKey(for: 2)
                == "analysis.sales.count.other"
        )
    }

    @Test("Analytics exposes only monthly-compatible periods and describes the visible value change")
    func filtersMonthlyHistoryForTheSelectedPeriod() throws {
        #expect(
            PortfolioAnalyticsPeriod.allCases == [
                .threeMonths,
                .sixMonths,
                .oneYear,
                .all,
            ]
        )

        let april = historyPoint(year: 2026, month: 4, day: 30, value: 100)
        let may = historyPoint(year: 2026, month: 5, day: 31, value: 110)
        let june = historyPoint(year: 2026, month: 6, day: 30, value: 120)
        let july = historyPoint(year: 2026, month: 7, day: 15, value: 130, isCurrent: true)
        let asOf = utcDate(year: 2026, month: 7, day: 15)

        let snapshot = PortfolioAnalyticsEngine().snapshot(
            valuation: valuation(
                totalValueEUR: 130,
                history: [april, may, june, july]
            ),
            period: .threeMonths,
            asOf: asOf,
            calendar: utcCalendar
        )

        #expect(snapshot.period == .threeMonths)
        #expect(snapshot.history.map(\.date) == [may.date, june.date, july.date])
        #expect(snapshot.currentValueEUR == 130)

        let change = try #require(snapshot.valueChange)
        #expect(change.startValueEUR == 110)
        #expect(change.endValueEUR == 130)
        #expect(change.amountEUR == 20)
        #expect(change.percentage == Decimal(20) / Decimal(110) * 100)
    }

    @Test("Six months includes the current month and the five preceding months")
    func filtersSixMonthsOfHistory() {
        let january = historyPoint(year: 2026, month: 1, day: 31, value: 90)
        let february = historyPoint(year: 2026, month: 2, day: 28, value: 100)
        let july = historyPoint(year: 2026, month: 7, day: 15, value: 130, isCurrent: true)
        let snapshot = PortfolioAnalyticsEngine().snapshot(
            valuation: valuation(
                totalValueEUR: 130,
                history: [january, february, july]
            ),
            period: .sixMonths,
            asOf: utcDate(year: 2026, month: 7, day: 15),
            calendar: utcCalendar
        )

        #expect(snapshot.history.map(\.date) == [february.date, july.date])
    }

    @Test("Performance uses only comparable assets and ranks gains deterministically")
    func buildsComparablePerformanceSummary() throws {
        let leadingID = UUID(uuidString: "A1000000-0000-4000-8000-000000000001")!
        let secondID = UUID(uuidString: "A1000000-0000-4000-8000-000000000002")!
        let snapshot = PortfolioAnalyticsEngine().snapshot(
            valuation: valuation(
                totalValueEUR: 1_900,
                assetValuations: [
                    assetValuation(
                        id: secondID,
                        name: "Lingot",
                        categoryID: AssetCategory.bar.rawValue,
                        metal: .gold,
                        valueEUR: 800,
                        purchaseCostEUR: 700
                    ),
                    assetValuation(
                        id: leadingID,
                        name: "Napoléon",
                        categoryID: AssetCategory.coin.rawValue,
                        metal: .gold,
                        valueEUR: 1_000,
                        purchaseCostEUR: 700
                    ),
                    assetValuation(
                        name: "Sans prix d’achat",
                        categoryID: AssetCategory.jewelry.rawValue,
                        metal: .gold,
                        valueEUR: 100
                    ),
                ]
            ),
            period: .all
        )

        let performance = snapshot.performance
        #expect(performance.currentValueEUR == 1_800)
        #expect(performance.purchaseCostEUR == 1_400)
        #expect(performance.unrealizedGainEUR == 400)
        #expect(performance.returnPercentage == Decimal(400) / Decimal(1_400) * 100)
        #expect(performance.rankedAssets.map(\.assetID) == [leadingID, secondID])
        #expect(performance.coverage.includedRecordCount == 2)
        #expect(performance.coverage.totalRecordCount == 3)
        #expect(!performance.coverage.isComplete)
        #expect(performance.categories.map(\.categoryID) == [
            AssetCategory.coin.rawValue,
            AssetCategory.bar.rawValue,
        ])
    }

    @Test("The selected monthly period also scopes realized sales")
    func filtersSalesForTheSelectedPeriod() {
        let sales = [
            completeSale(year: 2026, month: 4, day: 30, grossProceeds: 100),
            completeSale(year: 2026, month: 5, day: 31, grossProceeds: 110),
            completeSale(year: 2026, month: 6, day: 30, grossProceeds: 120),
            completeSale(year: 2026, month: 7, day: 15, grossProceeds: 130),
            completeSale(year: 2026, month: 8, day: 1, grossProceeds: 999),
        ]
        let asOf = utcDate(year: 2026, month: 7, day: 15)
        let engine = PortfolioAnalyticsEngine()

        let threeMonths = engine.snapshot(
            valuation: valuation(totalValueEUR: 1_000),
            sales: sales,
            period: .threeMonths,
            asOf: asOf,
            calendar: utcCalendar
        )
        let all = engine.snapshot(
            valuation: valuation(totalValueEUR: 1_000),
            sales: sales,
            period: .all,
            asOf: asOf,
            calendar: utcCalendar
        )

        #expect(threeMonths.sales.saleCount == 3)
        #expect(threeMonths.sales.netReceivedEUR == 360)
        #expect(all.sales.saleCount == 4)
        #expect(all.sales.netReceivedEUR == 460)
    }

    @Test("Incomplete history never becomes a zero-value performance")
    func incompleteHistoryDoesNotProduceAValueChange() {
        let complete = PortfolioHistoryPoint(
            date: utcDate(year: 2026, month: 6, day: 30),
            valueEUR: 1_000,
            valuedRecordCount: 1,
            totalHeldRecordCount: 1,
            isCurrent: false
        )
        let unavailable = PortfolioHistoryPoint(
            date: utcDate(year: 2026, month: 7, day: 15),
            valueEUR: 0,
            valuedRecordCount: 0,
            totalHeldRecordCount: 1,
            isCurrent: true
        )

        let snapshot = PortfolioAnalyticsEngine().snapshot(
            valuation: valuation(
                totalValueEUR: 0,
                history: [complete, unavailable]
            ),
            period: .all,
            asOf: utcDate(year: 2026, month: 7, day: 15),
            calendar: utcCalendar
        )

        #expect(snapshot.historyCoverage.hasIncompleteValuations)
        #expect(snapshot.valueChange == nil)
    }

    @Test("A partial current valuation is not presented as the whole vault value")
    func partialCurrentValuationStaysUnavailable() {
        let snapshot = PortfolioAnalyticsEngine().snapshot(
            valuation: valuation(
                totalValueEUR: 1_000,
                assetValuations: [
                    assetValuation(
                        name: "Valorisé",
                        categoryID: AssetCategory.coin.rawValue,
                        metal: .gold,
                        valueEUR: 1_000
                    ),
                    assetValuation(
                        name: "À compléter",
                        categoryID: AssetCategory.jewelry.rawValue,
                        metal: .gold,
                        valueEUR: nil,
                        status: .missingWeight
                    ),
                ]
            ),
            period: .all
        )

        #expect(snapshot.currentValueEUR == nil)
        #expect(
            snapshot.insights.contains(
                .valuationDataIncomplete(missingRecordCount: 1)
            )
        )
    }

    @Test("Unknown purchase dates are surfaced and do not produce a precise change")
    func unknownPurchaseDatesAreExplicit() {
        let june = historyPoint(year: 2026, month: 6, day: 30, value: 1_000)
        let july = historyPoint(
            year: 2026,
            month: 7,
            day: 15,
            value: 1_100,
            isCurrent: true
        )

        let snapshot = PortfolioAnalyticsEngine().snapshot(
            valuation: valuation(
                totalValueEUR: 1_100,
                history: [june, july],
                historyUsesUnknownPurchaseDates: true
            ),
            period: .all,
            asOf: utcDate(year: 2026, month: 7, day: 15),
            calendar: utcCalendar
        )

        #expect(snapshot.historyCoverage.usesUnknownPurchaseDates)
        #expect(snapshot.valueChange == nil)
    }

    @Test("Breakdowns keep missing values visible through record and value coverage")
    func buildsCoveredBreakdownsWithoutRenormalizingMissingLocations() throws {
        let coinID = UUID()
        let barID = UUID()
        let jewelryID = UUID()
        let unknownID = UUID()
        let assets = [
            assetValuation(
                id: coinID,
                name: "Pièce",
                categoryID: AssetCategory.coin.rawValue,
                metal: .gold,
                valueEUR: 600
            ),
            assetValuation(
                id: barID,
                name: "Lingot",
                categoryID: AssetCategory.bar.rawValue,
                metal: .silver,
                valueEUR: 300
            ),
            assetValuation(
                id: jewelryID,
                name: "Bijou",
                categoryID: AssetCategory.jewelry.rawValue,
                metal: .gold,
                valueEUR: 100
            ),
            assetValuation(
                id: unknownID,
                name: "Non valorisé",
                categoryID: AssetCategory.custom.rawValue,
                metal: .platinum,
                valueEUR: nil,
                status: .missingEURQuote
            ),
        ]

        let snapshot = PortfolioAnalyticsEngine().snapshot(
            valuation: valuation(
                totalValueEUR: 1_000,
                assetValuations: assets
            ),
            storageLocationsByAssetID: [
                coinID: "Domicile",
                barID: "Coffre bancaire",
                unknownID: "Domicile",
            ],
            period: .all
        )

        #expect(
            snapshot.metals.items.map(\.key) == [
                MarketMetal.gold.rawValue,
                MarketMetal.silver.rawValue,
            ]
        )
        #expect(snapshot.metals.items.map(\.valueEUR) == [700, 300])
        #expect(snapshot.metals.items.map(\.sharePercentage) == [70, 30])
        #expect(snapshot.metals.coverage.totalRecordCount == 4)
        #expect(snapshot.metals.coverage.includedRecordCount == 3)
        #expect(snapshot.metals.coverage.recordPercentage == 75)
        #expect(snapshot.metals.coverage.valuePercentage == 100)

        #expect(
            snapshot.categories.items.map(\.key) == [
                AssetCategory.coin.rawValue,
                AssetCategory.bar.rawValue,
                AssetCategory.jewelry.rawValue,
            ]
        )
        #expect(snapshot.categories.items.map(\.valueEUR) == [600, 300, 100])

        #expect(snapshot.storageLocations.items.map(\.key) == ["Domicile", "Coffre bancaire"])
        #expect(snapshot.storageLocations.items.map(\.valueEUR) == [600, 300])
        #expect(snapshot.storageLocations.items.map(\.sharePercentage) == [60, 30])
        #expect(snapshot.storageLocations.coverage.totalRecordCount == 4)
        #expect(snapshot.storageLocations.coverage.includedRecordCount == 2)
        #expect(snapshot.storageLocations.coverage.recordPercentage == 50)
        #expect(snapshot.storageLocations.coverage.representedValueEUR == 900)
        #expect(snapshot.storageLocations.coverage.totalKnownValueEUR == 1_000)
        #expect(snapshot.storageLocations.coverage.valuePercentage == 90)
    }

    @Test("Sales totals use net proceeds, one global return rate, and explicit coverage")
    func summarizesSalesWithoutAveragingIndividualRates() throws {
        let sales = [
            PortfolioAnalyticsSaleEntry(
                id: UUID(),
                soldAt: utcDate(year: 2026, month: 6, day: 10),
                grossProceedsEUR: 3_120,
                feesEUR: 35,
                purchaseCostEUR: 2_500,
                spotValueAtSaleEUR: 2_900
            ),
            PortfolioAnalyticsSaleEntry(
                id: UUID(),
                soldAt: utcDate(year: 2026, month: 7, day: 2),
                grossProceedsEUR: 1_510,
                feesEUR: 10,
                purchaseCostEUR: nil,
                spotValueAtSaleEUR: 1_600
            ),
        ]

        let snapshot = PortfolioAnalyticsEngine().snapshot(
            valuation: valuation(totalValueEUR: 1_000),
            sales: sales,
            period: .all
        )

        #expect(snapshot.sales.saleCount == 2)
        #expect(snapshot.sales.netReceivedEUR == 4_585)
        #expect(snapshot.sales.realizedResultEUR == 585)
        #expect(snapshot.sales.realizedRatePercentage == Decimal(585) / Decimal(2_500) * 100)
        #expect(snapshot.sales.grossProceedsComparedToSpotEUR == 130)
        #expect(snapshot.sales.coverage.netReceivedSaleCount == 2)
        #expect(snapshot.sales.coverage.realizedResultSaleCount == 1)
        #expect(snapshot.sales.coverage.spotComparisonSaleCount == 2)
        #expect(snapshot.sales.coverage.totalSaleCount == 2)
    }

    @Test("Unavailable inputs stay unavailable and become clear data-quality insights")
    func avoidsInventedMetricsWhenInputsAreMissing() {
        let missingValueAsset = assetValuation(
            name: "À compléter",
            categoryID: AssetCategory.coin.rawValue,
            metal: .gold,
            valueEUR: nil,
            status: .missingEURQuote
        )
        let incompleteSale = PortfolioAnalyticsSaleEntry(
            id: UUID(),
            soldAt: utcDate(year: 2026, month: 7, day: 2),
            grossProceedsEUR: 1_200,
            feesEUR: nil,
            purchaseCostEUR: 900,
            spotValueAtSaleEUR: nil
        )

        let snapshot = PortfolioAnalyticsEngine().snapshot(
            valuation: valuation(
                totalValueEUR: 0,
                assetValuations: [missingValueAsset]
            ),
            sales: [incompleteSale],
            period: .all
        )

        #expect(snapshot.currentValueEUR == nil)
        #expect(snapshot.valueChange == nil)
        #expect(snapshot.metals.items.isEmpty)
        #expect(snapshot.metals.coverage.recordPercentage == 0)
        #expect(snapshot.sales.netReceivedEUR == nil)
        #expect(snapshot.sales.realizedResultEUR == nil)
        #expect(snapshot.sales.realizedRatePercentage == nil)
        #expect(snapshot.sales.grossProceedsComparedToSpotEUR == nil)
        #expect(
            snapshot.insights == [
                .valuationDataIncomplete(missingRecordCount: 1),
                .salesPerformanceDataIncomplete(missingSaleCount: 1),
                .storageLocationDataIncomplete(missingRecordCount: 1),
            ]
        )
    }

    @Test("A partial spot comparison stays unavailable")
    func partialSpotComparisonIsNotPresentedAsATotal() {
        let summary = PortfolioSalesAnalyticsCalculator.summarize([
            completeSale(
                year: 2026,
                month: 6,
                day: 10,
                grossProceeds: 1_000
            ),
            PortfolioAnalyticsSaleEntry(
                id: UUID(),
                soldAt: utcDate(year: 2026, month: 7, day: 2),
                grossProceedsEUR: 1_200,
                feesEUR: 0,
                purchaseCostEUR: 1_000,
                spotValueAtSaleEUR: nil
            ),
        ])

        #expect(!summary.coverage.isSpotComparisonComplete)
        #expect(summary.grossProceedsComparedToSpotEUR == nil)
    }

    @Test("Complete data yields a small, deterministic set of useful insights")
    func buildsUsefulInsightsOnlyFromCompleteInputs() {
        let goldID = UUID()
        let silverID = UUID()
        let completeSale = PortfolioAnalyticsSaleEntry(
            id: UUID(),
            soldAt: utcDate(year: 2026, month: 7, day: 2),
            grossProceedsEUR: 1_200,
            feesEUR: 0,
            purchaseCostEUR: 1_000,
            spotValueAtSaleEUR: 1_100
        )
        let snapshot = PortfolioAnalyticsEngine().snapshot(
            valuation: valuation(
                totalValueEUR: 1_000,
                assetValuations: [
                    assetValuation(
                        id: goldID,
                        name: "Or",
                        categoryID: AssetCategory.coin.rawValue,
                        metal: .gold,
                        valueEUR: 600
                    ),
                    assetValuation(
                        id: silverID,
                        name: "Argent",
                        categoryID: AssetCategory.bar.rawValue,
                        metal: .silver,
                        valueEUR: 400
                    ),
                ]
            ),
            storageLocationsByAssetID: [
                goldID: "Domicile",
                silverID: "Coffre bancaire",
            ],
            sales: [completeSale],
            period: .all
        )

        #expect(
            snapshot.insights == [
                .majorityMetal(metal: .gold, sharePercentage: 60),
                .realizedSalesResult(amountEUR: 200),
            ]
        )
        #expect(snapshot.insights.count <= 3)
    }

    private func valuation(
        totalValueEUR: Decimal,
        history: [PortfolioHistoryPoint] = [],
        assetValuations: [AssetValuation]? = nil,
        historyUsesUnknownPurchaseDates: Bool = false
    ) -> PortfolioValuation {
        let resolvedAssetValuations = assetValuations ?? [
            assetValuation(
                name: "Actif valorisé",
                categoryID: AssetCategory.coin.rawValue,
                metal: .gold,
                valueEUR: totalValueEUR
            ),
        ]
        let valuedRecordCount = resolvedAssetValuations.count {
            $0.estimatedValueEUR != nil
        }
        return PortfolioValuation(
            totalEstimatedValueEUR: totalValueEUR,
            totalPurchaseCostEUR: nil,
            totalGainEUR: nil,
            gainPercentage: nil,
            assetValuations: resolvedAssetValuations,
            metals: [],
            categories: [],
            coverage: PortfolioCoverage(
                totalRecordCount: resolvedAssetValuations.count,
                valuedRecordCount: valuedRecordCount,
                performanceRecordCount: 0,
                totalObjectCount: resolvedAssetValuations.count,
                valuedObjectCount: valuedRecordCount
            ),
            history: history,
            historyUsesUnknownPurchaseDates: historyUsesUnknownPurchaseDates
        )
    }

    private func assetValuation(
        id: UUID = UUID(),
        name: String,
        categoryID: String,
        metal: MarketMetal?,
        valueEUR: Decimal?,
        purchaseCostEUR: Decimal? = nil,
        status: PortfolioAssetValuationStatus = .valued
    ) -> AssetValuation {
        AssetValuation(
            assetID: id,
            name: name,
            categoryID: categoryID,
            metal: metal,
            quantity: 1,
            fineWeightGrams: valueEUR == nil ? nil : 1,
            estimatedValueEUR: valueEUR,
            purchaseCost: purchaseCostEUR,
            purchaseCurrency: purchaseCostEUR == nil ? nil : .eur,
            currentValueInPurchaseCurrency: purchaseCostEUR == nil ? nil : valueEUR,
            purchaseCostEUR: purchaseCostEUR,
            gainInPurchaseCurrency: valueEUR.flatMap { value in
                purchaseCostEUR.map { value - $0 }
            },
            gainEUR: valueEUR.flatMap { value in
                purchaseCostEUR.map { value - $0 }
            },
            gainPercentage: valueEUR.flatMap { value in
                purchaseCostEUR.flatMap { cost in
                    cost == 0 ? nil : (value - cost) / cost * 100
                }
            },
            status: status
        )
    }

    private func historyPoint(
        year: Int,
        month: Int,
        day: Int,
        value: Decimal,
        isCurrent: Bool = false
    ) -> PortfolioHistoryPoint {
        PortfolioHistoryPoint(
            date: utcDate(year: year, month: month, day: day),
            valueEUR: value,
            valuedRecordCount: 1,
            totalHeldRecordCount: 1,
            isCurrent: isCurrent
        )
    }

    private func completeSale(
        year: Int,
        month: Int,
        day: Int,
        grossProceeds: Decimal
    ) -> PortfolioAnalyticsSaleEntry {
        PortfolioAnalyticsSaleEntry(
            id: UUID(),
            soldAt: utcDate(year: year, month: month, day: day),
            grossProceedsEUR: grossProceeds,
            feesEUR: 0,
            purchaseCostEUR: grossProceeds,
            spotValueAtSaleEUR: grossProceeds
        )
    }

    private func utcDate(year: Int, month: Int, day: Int) -> Date {
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
