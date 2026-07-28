import Foundation

nonisolated enum PortfolioAnalyticsPeriod: String, CaseIterable, Equatable, Sendable {
    case threeMonths
    case oneYear
    case all

    func filter(
        _ points: [PortfolioHistoryPoint],
        asOf: Date,
        calendar: Calendar = .current
    ) -> [PortfolioHistoryPoint] {
        let sortedPoints = points
            .filter { $0.date <= asOf }
            .sorted { $0.date < $1.date }
        guard let startDate = startDate(asOf: asOf, calendar: calendar) else {
            return sortedPoints
        }
        return sortedPoints.filter { $0.date >= startDate }
    }

    func filter(
        _ sales: [PortfolioAnalyticsSaleEntry],
        asOf: Date,
        calendar: Calendar = .current
    ) -> [PortfolioAnalyticsSaleEntry] {
        let visibleSales = sales.filter { $0.soldAt <= asOf }
        guard let startDate = startDate(asOf: asOf, calendar: calendar) else {
            return visibleSales
        }
        return visibleSales.filter { $0.soldAt >= startDate }
    }

    private func startDate(
        asOf: Date,
        calendar: Calendar
    ) -> Date? {
        guard self != .all,
              let currentMonthStart = calendar.dateInterval(
                  of: .month,
                  for: asOf
              )?.start,
              let monthOffset
        else {
            return nil
        }
        return calendar.date(
            byAdding: .month,
            value: monthOffset,
            to: currentMonthStart
        )
    }

    private var monthOffset: Int? {
        switch self {
        case .threeMonths:
            -2
        case .oneYear:
            -11
        case .all:
            nil
        }
    }
}

nonisolated struct PortfolioAnalyticsValueChange: Equatable, Sendable {
    let startValueEUR: Decimal
    let endValueEUR: Decimal
    let amountEUR: Decimal
    let percentage: Decimal?
}

nonisolated struct PortfolioAnalyticsHistoryCoverage: Equatable, Sendable {
    let hasIncompleteValuations: Bool
    let usesUnknownPurchaseDates: Bool

    var canPresentChart: Bool {
        !hasIncompleteValuations
    }

    var canPresentValueChange: Bool {
        canPresentChart && !usesUnknownPurchaseDates
    }
}

nonisolated struct PortfolioAnalyticsSnapshot: Equatable, Sendable {
    let period: PortfolioAnalyticsPeriod
    let currentValueEUR: Decimal?
    let valueChange: PortfolioAnalyticsValueChange?
    let history: [PortfolioHistoryPoint]
    let historyCoverage: PortfolioAnalyticsHistoryCoverage
    let metals: PortfolioAnalyticsBreakdown
    let categories: PortfolioAnalyticsBreakdown
    let storageLocations: PortfolioAnalyticsBreakdown
    let sales: PortfolioSalesAnalyticsSummary
    let insights: [PortfolioAnalyticsInsight]
}

nonisolated struct PortfolioAnalyticsEngine: Sendable {
    init() {}

    func snapshot(
        valuation: PortfolioValuation,
        storageLocationsByAssetID: [UUID: String] = [:],
        sales: [PortfolioAnalyticsSaleEntry] = [],
        period: PortfolioAnalyticsPeriod,
        asOf: Date = Date(),
        calendar: Calendar = .current
    ) -> PortfolioAnalyticsSnapshot {
        let visibleHistory = period.filter(
            valuation.history,
            asOf: asOf,
            calendar: calendar
        )
        let metals = PortfolioAnalyticsBreakdownBuilder.build(
            from: valuation.assetValuations,
            key: { $0.metal?.rawValue }
        )
        let categories = PortfolioAnalyticsBreakdownBuilder.build(
            from: valuation.assetValuations,
            key: \.categoryID
        )
        let storageLocations = PortfolioAnalyticsBreakdownBuilder.build(
            from: valuation.assetValuations,
            key: { storageLocationsByAssetID[$0.assetID] }
        )
        let visibleSales = period.filter(
            sales,
            asOf: asOf,
            calendar: calendar
        )
        let historyCoverage = PortfolioAnalyticsHistoryCoverage(
            hasIncompleteValuations: visibleHistory.contains {
                $0.valuedRecordCount < $0.totalHeldRecordCount
            },
            usesUnknownPurchaseDates: valuation.historyUsesUnknownPurchaseDates
                && !visibleHistory.isEmpty
        )
        let salesSummary = PortfolioSalesAnalyticsCalculator.summarize(
            visibleSales
        )
        return PortfolioAnalyticsSnapshot(
            period: period,
            currentValueEUR: currentValue(from: valuation),
            valueChange: historyCoverage.canPresentValueChange
                ? valueChange(in: visibleHistory)
                : nil,
            history: visibleHistory,
            historyCoverage: historyCoverage,
            metals: metals,
            categories: categories,
            storageLocations: storageLocations,
            sales: salesSummary,
            insights: PortfolioAnalyticsInsightBuilder.build(
                valuation: valuation,
                storageLocationsByAssetID: storageLocationsByAssetID,
                metals: metals,
                sales: salesSummary
            )
        )
    }

    private func currentValue(from valuation: PortfolioValuation) -> Decimal? {
        if valuation.coverage.totalRecordCount == 0 {
            return 0
        }
        guard valuation.coverage.valuedRecordCount
                == valuation.coverage.totalRecordCount
        else {
            // A partial subtotal must never be presented as the value of the
            // whole vault. The data-quality insight explains what is missing.
            return nil
        }
        return valuation.totalEstimatedValueEUR
    }

    private func valueChange(
        in history: [PortfolioHistoryPoint]
    ) -> PortfolioAnalyticsValueChange? {
        guard let first = history.first,
              let last = history.last,
              first.id != last.id
        else {
            return nil
        }
        let amount = last.valueEUR - first.valueEUR
        return PortfolioAnalyticsValueChange(
            startValueEUR: first.valueEUR,
            endValueEUR: last.valueEUR,
            amountEUR: amount,
            percentage: first.valueEUR == 0
                ? nil
                : amount / first.valueEUR * 100
        )
    }
}
