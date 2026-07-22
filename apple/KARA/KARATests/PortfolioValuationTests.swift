import Foundation
import Testing
@testable import KARA

@Suite("Portfolio valuation")
struct PortfolioValuationTests {
    @Test("Fine weight uses quantity and fineness before karats, then values the metal in EUR")
    func valuesFineMetalContent() throws {
        let asset = PortfolioAssetSnapshot(
            name: "Deux pièces",
            categoryID: "goldCoin",
            metal: .gold,
            quantity: 2,
            grossWeightGrams: 100,
            finenessPermille: 900,
            metalKarat: 24,
            purchaseCost: 10_000,
            purchaseCurrency: .eur
        )
        let quote = SpotQuote(
            metal: .gold,
            currency: .eur,
            price: Decimal(string: "3110.34768")!,
            unit: MarketUnit(code: .troyOunce, grams: Decimal(string: "31.1034768")!),
            sourceUpdatedAt: Date(timeIntervalSince1970: 1_784_627_133)
        )
        let market = PortfolioMarketSnapshot(currentQuotes: [quote])

        let valuation = PortfolioValuationEngine().valuate(assets: [asset], market: market)
        let item = try #require(valuation.assetValuations.first)

        #expect(item.status == .valued)
        #expect(item.fineWeightGrams == 180)
        #expect(item.estimatedValueEUR == 18_000)
        #expect(item.purchaseCostEUR == 10_000)
        #expect(item.gainEUR == 8_000)
        #expect(item.gainPercentage == 80)
        #expect(valuation.totalEstimatedValueEUR == 18_000)
        #expect(valuation.coverage.valuedRecordCount == 1)
        #expect(valuation.metals.first?.fineWeightGrams == 180)
    }

    @Test("Karats provide purity when fineness is absent")
    func fallsBackToKarats() throws {
        let asset = PortfolioAssetSnapshot(
            name: "Bijou 18 carats",
            categoryID: "jewelry",
            metal: .gold,
            grossWeightGrams: 24,
            metalKarat: 18
        )
        let market = PortfolioMarketSnapshot(currentQuotes: [
            makeQuote(metal: .gold, currency: .eur, price: Decimal(string: "3110.34768")!),
        ])

        let item = try #require(
            PortfolioValuationEngine()
                .valuate(assets: [asset], market: market)
                .assetValuations.first
        )

        #expect(item.fineWeightGrams == 18)
        #expect(item.estimatedValueEUR == 1_800)
    }

    @Test("Foreign-currency gain is computed in purchase currency then converted at the implicit live rate")
    func convertsForeignCurrencyGain() throws {
        let ounce = Decimal(string: "31.1034768")!
        let asset = PortfolioAssetSnapshot(
            name: "Once d'or",
            categoryID: "goldBar",
            metal: .gold,
            grossWeightGrams: ounce,
            finenessPermille: 1_000,
            purchaseCost: 2_500,
            purchaseCurrency: .usd
        )
        let market = PortfolioMarketSnapshot(currentQuotes: [
            makeQuote(metal: .gold, currency: .eur, price: 3_000),
            makeQuote(metal: .gold, currency: .usd, price: 3_750),
        ])

        let valuation = PortfolioValuationEngine().valuate(assets: [asset], market: market)
        let item = try #require(valuation.assetValuations.first)

        #expect(item.currentValueInPurchaseCurrency == 3_750)
        #expect(item.gainInPurchaseCurrency == 1_250)
        #expect(item.purchaseCostEUR == 2_000)
        #expect(item.gainEUR == 1_000)
        #expect(item.gainPercentage == 50)
        #expect(valuation.totalGainEUR == 1_000)
        #expect(valuation.gainPercentage == 50)
    }

    @Test("A zero purchase cost produces a gain but no undefined percentage")
    func handlesZeroPurchaseCost() throws {
        let asset = PortfolioAssetSnapshot(
            name: "Actif reçu",
            categoryID: "goldCoin",
            metal: .gold,
            grossWeightGrams: Decimal(string: "31.1034768")!,
            finenessPermille: 1_000,
            purchaseCost: 0,
            purchaseCurrency: .eur
        )
        let market = PortfolioMarketSnapshot(currentQuotes: [
            makeQuote(metal: .gold, currency: .eur, price: 3_000),
        ])

        let valuation = PortfolioValuationEngine().valuate(assets: [asset], market: market)
        let item = try #require(valuation.assetValuations.first)

        #expect(item.gainEUR == 3_000)
        #expect(item.gainPercentage == nil)
        #expect(valuation.totalPurchaseCostEUR == 0)
        #expect(valuation.totalGainEUR == 3_000)
        #expect(valuation.gainPercentage == nil)
    }

    @Test("History includes assets held at each month end and appends the live valuation")
    func buildsAcquisitionAwareHistory() throws {
        let ounce = Decimal(string: "31.1034768")!
        let unknownAcquisition = PortfolioAssetSnapshot(
            name: "Ancien lingot",
            categoryID: "goldBar",
            metal: .gold,
            grossWeightGrams: ounce,
            finenessPermille: 1_000,
            purchaseDate: nil
        )
        let februaryAcquisition = PortfolioAssetSnapshot(
            name: "Nouveau lingot",
            categoryID: "goldBar",
            metal: .gold,
            grossWeightGrams: ounce,
            finenessPermille: 1_000,
            purchaseDate: utcDate(year: 2026, month: 2, day: 15)
        )
        let monthly = MonthlyDataset(
            unit: MarketUnit(code: .troyOunce, grams: ounce),
            series: [
                MonthlySeries(metal: .gold, observations: [
                    MonthlyObservation(month: "2026-01", prices: ["EUR": 10]),
                    MonthlyObservation(month: "2026-02", prices: ["EUR": 20]),
                ]),
            ]
        )
        let market = PortfolioMarketSnapshot(
            currentQuotes: [makeQuote(metal: .gold, currency: .eur, price: 3_000)],
            monthly: monthly
        )

        let valuation = PortfolioValuationEngine().valuate(
            assets: [unknownAcquisition, februaryAcquisition],
            market: market,
            historyMonths: 3,
            asOf: utcDate(year: 2026, month: 3, day: 15)
        )

        #expect(valuation.history.map(\.valueEUR) == [10, 40, 6_000])
        #expect(valuation.history.map(\.totalHeldRecordCount) == [1, 2, 2])
        #expect(valuation.history.map(\.isCurrent) == [false, false, true])
        #expect(valuation.historyUsesUnknownPurchaseDates)
    }

    @Test("The live history point excludes assets whose acquisition date is still in the future")
    func excludesFutureAcquisitionsFromLiveHistory() throws {
        let ounce = Decimal(string: "31.1034768")!
        let heldAsset = PortfolioAssetSnapshot(
            name: "Actif détenu",
            categoryID: "goldBar",
            metal: .gold,
            grossWeightGrams: ounce,
            finenessPermille: 1_000,
            purchaseDate: utcDate(year: 2026, month: 3, day: 1)
        )
        let futureAsset = PortfolioAssetSnapshot(
            name: "Acquisition future",
            categoryID: "goldBar",
            metal: .gold,
            grossWeightGrams: ounce,
            finenessPermille: 1_000,
            purchaseDate: utcDate(year: 2026, month: 4, day: 1)
        )
        let market = PortfolioMarketSnapshot(currentQuotes: [
            makeQuote(metal: .gold, currency: .eur, price: 3_000),
        ])

        let valuation = PortfolioValuationEngine().valuate(
            assets: [heldAsset, futureAsset],
            market: market,
            historyMonths: 1,
            asOf: utcDate(year: 2026, month: 3, day: 15)
        )

        #expect(valuation.history.map(\.valueEUR) == [3_000])
        #expect(valuation.history.map(\.valuedRecordCount) == [1])
        #expect(valuation.history.map(\.totalHeldRecordCount) == [1])
    }

    @Test("Full history begins with the first source-backed month when the earliest asset was acquired")
    func buildsFullHistoryFromEarliestAcquisition() throws {
        let ounce = Decimal(string: "31.1034768")!
        let asset = PortfolioAssetSnapshot(
            name: "Lingot historique",
            categoryID: "goldBar",
            metal: .gold,
            grossWeightGrams: ounce,
            finenessPermille: 1_000,
            purchaseDate: utcDate(year: 2002, month: 2, day: 15)
        )
        let monthly = MonthlyDataset(
            unit: MarketUnit(code: .troyOunce, grams: ounce),
            series: [
                MonthlySeries(metal: .gold, observations: [
                    MonthlyObservation(month: "2002-01", prices: ["EUR": 10]),
                    MonthlyObservation(month: "2002-02", prices: ["EUR": 20]),
                    MonthlyObservation(month: "2002-03", prices: ["EUR": 30]),
                ]),
            ]
        )
        let market = PortfolioMarketSnapshot(
            currentQuotes: [makeQuote(metal: .gold, currency: .eur, price: 40)],
            monthly: monthly
        )

        let valuation = PortfolioValuationEngine().valuate(
            assets: [asset],
            market: market,
            historyMonths: nil,
            asOf: utcDate(year: 2002, month: 4, day: 15)
        )

        #expect(valuation.history.map(\.valueEUR) == [20, 30, 40])
        #expect(valuation.history.map(\.totalHeldRecordCount) == [1, 1, 1])
    }

    @Test("Twelve-month history starts on the first day of the initial calendar month")
    func computesTwelveMonthVisibleStart() throws {
        let start = try #require(
            PortfolioHistoryPeriod.twelveMonths.startDate(
                asOf: utcDate(year: 2026, month: 7, day: 22),
                earliestHistoryDate: nil,
                calendar: utcCalendar
            )
        )

        #expect(start == utcDate(year: 2025, month: 8, day: 1))
    }

    @Test("Bounded history periods keep only points inside their calendar window")
    func filtersBoundedHistoryPeriods() {
        let points = [
            historyPoint(year: 2025, month: 7, day: 31),
            historyPoint(year: 2025, month: 8, day: 31),
            historyPoint(year: 2026, month: 2, day: 28),
            historyPoint(year: 2026, month: 5, day: 31),
            historyPoint(year: 2026, month: 7, day: 22),
        ]
        let asOf = utcDate(year: 2026, month: 7, day: 22)

        #expect(PortfolioHistoryPeriod.twelveMonths.filter(points, asOf: asOf, calendar: utcCalendar).count == 4)
        #expect(PortfolioHistoryPeriod.sixMonths.filter(points, asOf: asOf, calendar: utcCalendar).count == 3)
        #expect(PortfolioHistoryPeriod.threeMonths.filter(points, asOf: asOf, calendar: utcCalendar).count == 2)
        #expect(PortfolioHistoryPeriod.all.filter(points, asOf: asOf, calendar: utcCalendar) == points)
    }

    @Test("Full history does not invent values before the monthly dataset begins")
    func limitsFullHistoryToSourceCoverage() {
        let ounce = Decimal(string: "31.1034768")!
        let asset = PortfolioAssetSnapshot(
            name: "Acquisition antérieure aux données",
            categoryID: "goldBar",
            metal: .gold,
            grossWeightGrams: ounce,
            finenessPermille: 1_000,
            purchaseDate: utcDate(year: 1980, month: 1, day: 1)
        )
        let monthly = MonthlyDataset(
            unit: MarketUnit(code: .troyOunce, grams: ounce),
            series: [
                MonthlySeries(metal: .gold, observations: [
                    MonthlyObservation(month: "1999-01", prices: ["EUR": 10]),
                    MonthlyObservation(month: "1999-02", prices: ["EUR": 20]),
                ]),
            ]
        )
        let market = PortfolioMarketSnapshot(
            currentQuotes: [makeQuote(metal: .gold, currency: .eur, price: 30)],
            monthly: monthly
        )

        let history = PortfolioValuationEngine().valuate(
            assets: [asset],
            market: market,
            historyMonths: nil,
            asOf: utcDate(year: 1999, month: 3, day: 15)
        ).history

        #expect(history.map(\.valueEUR) == [10, 20, 30])
        #expect(utcCalendar.component(.year, from: history[0].date) == 1999)
    }

    @Test("Coverage separates incomplete assets and missing market quotes without inventing zero values")
    func reportsPartialCoverage() throws {
        let assets = [
            PortfolioAssetSnapshot(
                name: "Or valorisé",
                categoryID: "goldBar",
                metal: .gold,
                quantity: 2,
                grossWeightGrams: 10,
                finenessPermille: 1_000
            ),
            PortfolioAssetSnapshot(
                name: "Titre manquant",
                categoryID: "goldCoin",
                metal: .gold,
                quantity: 3,
                grossWeightGrams: 10
            ),
            PortfolioAssetSnapshot(
                name: "Argent sans cours",
                categoryID: "goldCoin",
                metal: .silver,
                quantity: 4,
                grossWeightGrams: 10,
                finenessPermille: 1_000
            ),
        ]
        let market = PortfolioMarketSnapshot(currentQuotes: [
            makeQuote(metal: .gold, currency: .eur, price: Decimal(string: "3110.34768")!),
        ])

        let valuation = PortfolioValuationEngine().valuate(assets: assets, market: market)

        #expect(valuation.coverage.totalRecordCount == 3)
        #expect(valuation.coverage.valuedRecordCount == 1)
        #expect(valuation.coverage.totalObjectCount == 9)
        #expect(valuation.coverage.valuedObjectCount == 2)
        #expect(valuation.coverage.valuationPercentage! > Decimal(string: "33.33")!)
        #expect(valuation.coverage.valuationPercentage! < Decimal(string: "33.34")!)
        #expect(valuation.assetValuations.map(\.status) == [.valued, .missingPurity, .missingEURQuote])
        #expect(valuation.metals.first(where: { $0.metal == .silver })?.fineWeightGrams == 40)
        #expect(valuation.metals.first(where: { $0.metal == .silver })?.estimatedValueEUR == nil)
    }

    private func makeQuote(
        metal: MarketMetal,
        currency: MarketCurrency,
        price: Decimal
    ) -> SpotQuote {
        SpotQuote(
            metal: metal,
            currency: currency,
            price: price,
            unit: MarketUnit(code: .troyOunce, grams: Decimal(string: "31.1034768")!),
            sourceUpdatedAt: Date(timeIntervalSince1970: 1_784_627_133)
        )
    }

    private func utcDate(year: Int, month: Int, day: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func historyPoint(year: Int, month: Int, day: Int) -> PortfolioHistoryPoint {
        PortfolioHistoryPoint(
            date: utcDate(year: year, month: month, day: day),
            valueEUR: 1,
            valuedRecordCount: 1,
            totalHeldRecordCount: 1,
            isCurrent: false
        )
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
