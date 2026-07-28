import Foundation

/// A deliberately small vocabulary of reader-facing facts.
nonisolated enum PortfolioAnalyticsInsight: Equatable, Sendable {
    case valuationDataIncomplete(missingRecordCount: Int)
    case salesPerformanceDataIncomplete(missingSaleCount: Int)
    case storageLocationDataIncomplete(missingRecordCount: Int)
    case majorityMetal(metal: MarketMetal, sharePercentage: Decimal)
    case realizedSalesResult(amountEUR: Decimal)
}

nonisolated enum PortfolioAnalyticsInsightBuilder {
    static func build(
        valuation: PortfolioValuation,
        storageLocationsByAssetID: [UUID: String],
        metals: PortfolioAnalyticsBreakdown,
        sales: PortfolioSalesAnalyticsSummary
    ) -> [PortfolioAnalyticsInsight] {
        var insights: [PortfolioAnalyticsInsight] = []

        let missingValuationCount = max(
            0,
            valuation.coverage.totalRecordCount - valuation.coverage.valuedRecordCount
        )
        if missingValuationCount > 0 {
            insights.append(
                .valuationDataIncomplete(missingRecordCount: missingValuationCount)
            )
        }

        let missingSalesPerformanceCount = max(
            0,
            sales.coverage.totalSaleCount - sales.coverage.realizedResultSaleCount
        )
        if missingSalesPerformanceCount > 0 {
            insights.append(
                .salesPerformanceDataIncomplete(
                    missingSaleCount: missingSalesPerformanceCount
                )
            )
        }

        let missingLocationCount = valuation.assetValuations.count { valuation in
            guard let location = storageLocationsByAssetID[valuation.assetID] else {
                return true
            }
            return location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if missingLocationCount > 0 {
            insights.append(
                .storageLocationDataIncomplete(
                    missingRecordCount: missingLocationCount
                )
            )
        }

        if metals.coverage.isComplete,
           let leadingMetal = metals.items.first,
           let sharePercentage = leadingMetal.sharePercentage,
           sharePercentage > 50,
           let metal = MarketMetal(rawValue: leadingMetal.key)
        {
            insights.append(
                .majorityMetal(
                    metal: metal,
                    sharePercentage: sharePercentage
                )
            )
        }

        if sales.saleCount > 0,
           sales.coverage.isRealizedResultComplete,
           let realizedResult = sales.realizedResultEUR
        {
            insights.append(
                .realizedSalesResult(amountEUR: realizedResult)
            )
        }

        return Array(insights.prefix(3))
    }
}
