import Foundation

nonisolated struct PortfolioPerformanceAsset: Equatable, Identifiable, Sendable {
    let assetID: UUID
    let name: String
    let categoryID: String
    let currentValueEUR: Decimal
    let purchaseCostEUR: Decimal
    let unrealizedGainEUR: Decimal
    let returnPercentage: Decimal?

    var id: UUID { assetID }
}

nonisolated struct PortfolioPerformanceCategory: Equatable, Identifiable, Sendable {
    let categoryID: String
    let currentValueEUR: Decimal
    let purchaseCostEUR: Decimal
    let unrealizedGainEUR: Decimal
    let recordCount: Int

    var id: String { categoryID }
}

nonisolated struct PortfolioPerformanceCoverage: Equatable, Sendable {
    let includedRecordCount: Int
    let totalRecordCount: Int

    var isComplete: Bool {
        includedRecordCount == totalRecordCount
    }

    var percentage: Decimal? {
        guard totalRecordCount > 0 else { return nil }
        return Decimal(includedRecordCount) / Decimal(totalRecordCount) * 100
    }
}

nonisolated struct PortfolioPerformanceSummary: Equatable, Sendable {
    let currentValueEUR: Decimal?
    let purchaseCostEUR: Decimal?
    let unrealizedGainEUR: Decimal?
    let returnPercentage: Decimal?
    let rankedAssets: [PortfolioPerformanceAsset]
    let categories: [PortfolioPerformanceCategory]
    let coverage: PortfolioPerformanceCoverage

    var isAvailable: Bool {
        !rankedAssets.isEmpty
    }
}

nonisolated enum PortfolioPerformanceCalculator {
    static func summarize(
        _ valuations: [AssetValuation]
    ) -> PortfolioPerformanceSummary {
        let assets = valuations.compactMap(makeAsset)
        let coverage = PortfolioPerformanceCoverage(
            includedRecordCount: assets.count,
            totalRecordCount: valuations.count
        )

        guard !assets.isEmpty else {
            return PortfolioPerformanceSummary(
                currentValueEUR: nil,
                purchaseCostEUR: nil,
                unrealizedGainEUR: nil,
                returnPercentage: nil,
                rankedAssets: [],
                categories: [],
                coverage: coverage
            )
        }

        let currentValue = assets.map(\.currentValueEUR).reduce(0, +)
        let purchaseCost = assets.map(\.purchaseCostEUR).reduce(0, +)
        let unrealizedGain = assets.map(\.unrealizedGainEUR).reduce(0, +)

        return PortfolioPerformanceSummary(
            currentValueEUR: currentValue,
            purchaseCostEUR: purchaseCost,
            unrealizedGainEUR: unrealizedGain,
            returnPercentage: purchaseCost == 0
                ? nil
                : unrealizedGain / purchaseCost * 100,
            rankedAssets: assets.sorted(by: ranksBefore),
            categories: categories(from: assets),
            coverage: coverage
        )
    }

    private static func makeAsset(
        _ valuation: AssetValuation
    ) -> PortfolioPerformanceAsset? {
        guard let currentValue = valuation.estimatedValueEUR,
              let purchaseCost = valuation.purchaseCostEUR,
              let unrealizedGain = valuation.gainEUR
        else {
            return nil
        }

        return PortfolioPerformanceAsset(
            assetID: valuation.assetID,
            name: valuation.name,
            categoryID: valuation.categoryID,
            currentValueEUR: currentValue,
            purchaseCostEUR: purchaseCost,
            unrealizedGainEUR: unrealizedGain,
            returnPercentage: purchaseCost == 0
                ? nil
                : unrealizedGain / purchaseCost * 100
        )
    }

    private static func ranksBefore(
        _ lhs: PortfolioPerformanceAsset,
        _ rhs: PortfolioPerformanceAsset
    ) -> Bool {
        if lhs.unrealizedGainEUR != rhs.unrealizedGainEUR {
            return lhs.unrealizedGainEUR > rhs.unrealizedGainEUR
        }
        let nameOrder = lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        if nameOrder != .orderedSame {
            return nameOrder == .orderedAscending
        }
        return lhs.assetID.uuidString < rhs.assetID.uuidString
    }

    private static func categories(
        from assets: [PortfolioPerformanceAsset]
    ) -> [PortfolioPerformanceCategory] {
        Dictionary(grouping: assets, by: \.categoryID)
            .map { categoryID, assets in
                let currentValue = assets.map(\.currentValueEUR).reduce(0, +)
                let purchaseCost = assets.map(\.purchaseCostEUR).reduce(0, +)
                return PortfolioPerformanceCategory(
                    categoryID: categoryID,
                    currentValueEUR: currentValue,
                    purchaseCostEUR: purchaseCost,
                    unrealizedGainEUR: currentValue - purchaseCost,
                    recordCount: assets.count
                )
            }
            .sorted { lhs, rhs in
                if lhs.currentValueEUR != rhs.currentValueEUR {
                    return lhs.currentValueEUR > rhs.currentValueEUR
                }
                return lhs.categoryID < rhs.categoryID
            }
    }
}
