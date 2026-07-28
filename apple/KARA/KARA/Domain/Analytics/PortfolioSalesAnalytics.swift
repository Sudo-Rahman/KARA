import Foundation

/// Immutable sales data needed by analytics, deliberately independent from persistence.
nonisolated struct PortfolioAnalyticsSaleEntry: Equatable, Identifiable, Sendable {
    let id: UUID
    let soldAt: Date
    let grossProceedsEUR: Decimal?
    let feesEUR: Decimal?
    let purchaseCostEUR: Decimal?
    let spotValueAtSaleEUR: Decimal?
}

nonisolated struct PortfolioSalesAnalyticsCoverage: Equatable, Sendable {
    let totalSaleCount: Int
    let netReceivedSaleCount: Int
    let realizedResultSaleCount: Int
    let spotComparisonSaleCount: Int

    var isNetReceivedComplete: Bool {
        totalSaleCount == netReceivedSaleCount
    }

    var isRealizedResultComplete: Bool {
        totalSaleCount == realizedResultSaleCount
    }

    var isSpotComparisonComplete: Bool {
        totalSaleCount == spotComparisonSaleCount
    }
}

nonisolated struct PortfolioSalesAnalyticsSummary: Equatable, Sendable {
    let saleCount: Int
    let netReceivedEUR: Decimal?
    let realizedResultEUR: Decimal?
    let realizedRatePercentage: Decimal?
    let grossProceedsComparedToSpotEUR: Decimal?
    let coverage: PortfolioSalesAnalyticsCoverage
}

nonisolated enum PortfolioSalesAnalyticsCalculator {
    static func summarize(
        _ sales: [PortfolioAnalyticsSaleEntry]
    ) -> PortfolioSalesAnalyticsSummary {
        let netSales = sales.compactMap(netSale)
        let realizedSales = netSales.compactMap { netSale -> RealizedSale? in
            guard let purchaseCost = validAmount(netSale.sale.purchaseCostEUR) else {
                return nil
            }
            return RealizedSale(
                netReceivedEUR: netSale.netReceivedEUR,
                purchaseCostEUR: purchaseCost
            )
        }
        let spotComparisons = sales.compactMap { sale -> Decimal? in
            guard let grossProceeds = validAmount(sale.grossProceedsEUR),
                  let spotValue = validAmount(sale.spotValueAtSaleEUR)
            else {
                return nil
            }
            return grossProceeds - spotValue
        }

        let netReceived = optionalSum(netSales.map(\.netReceivedEUR))
        let realizedResult = optionalSum(
            realizedSales.map { $0.netReceivedEUR - $0.purchaseCostEUR }
        )
        let realizedPurchaseCost = realizedSales
            .map(\.purchaseCostEUR)
            .reduce(0, +)
        let spotComparisonIsComplete = spotComparisons.count == sales.count

        return PortfolioSalesAnalyticsSummary(
            saleCount: sales.count,
            netReceivedEUR: netReceived,
            realizedResultEUR: realizedResult,
            realizedRatePercentage: realizedPurchaseCost > 0
                ? realizedResult.map { $0 / realizedPurchaseCost * 100 }
                : nil,
            grossProceedsComparedToSpotEUR: spotComparisonIsComplete
                ? optionalSum(spotComparisons)
                : nil,
            coverage: PortfolioSalesAnalyticsCoverage(
                totalSaleCount: sales.count,
                netReceivedSaleCount: netSales.count,
                realizedResultSaleCount: realizedSales.count,
                spotComparisonSaleCount: spotComparisons.count
            )
        )
    }

    private static func netSale(
        _ sale: PortfolioAnalyticsSaleEntry
    ) -> NetSale? {
        guard let grossProceeds = validAmount(sale.grossProceedsEUR),
              let fees = validAmount(sale.feesEUR)
        else {
            return nil
        }
        return NetSale(
            sale: sale,
            netReceivedEUR: grossProceeds - fees
        )
    }

    private static func validAmount(_ amount: Decimal?) -> Decimal? {
        guard let amount, amount >= 0 else { return nil }
        return amount
    }

    private static func optionalSum(_ values: [Decimal]) -> Decimal? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }

    private struct NetSale {
        let sale: PortfolioAnalyticsSaleEntry
        let netReceivedEUR: Decimal
    }

    private struct RealizedSale {
        let netReceivedEUR: Decimal
        let purchaseCostEUR: Decimal
    }
}
