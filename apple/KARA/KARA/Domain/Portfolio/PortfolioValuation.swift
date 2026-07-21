import Foundation

nonisolated struct PortfolioAssetSnapshot: Equatable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let categoryID: String
    let metal: MarketMetal?
    let quantity: Int
    let grossWeightGrams: Decimal?
    let finenessPermille: Decimal?
    let metalKarat: Decimal?
    let purchaseCost: Decimal?
    let purchaseCurrency: MarketCurrency?
    let purchaseDate: Date?

    init(
        id: UUID = UUID(),
        name: String,
        categoryID: String,
        metal: MarketMetal?,
        quantity: Int = 1,
        grossWeightGrams: Decimal? = nil,
        finenessPermille: Decimal? = nil,
        metalKarat: Decimal? = nil,
        purchaseCost: Decimal? = nil,
        purchaseCurrency: MarketCurrency? = .eur,
        purchaseDate: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.categoryID = categoryID
        self.metal = metal
        self.quantity = quantity
        self.grossWeightGrams = grossWeightGrams
        self.finenessPermille = finenessPermille
        self.metalKarat = metalKarat
        self.purchaseCost = purchaseCost
        self.purchaseCurrency = purchaseCurrency
        self.purchaseDate = purchaseDate
    }
}

nonisolated struct PortfolioMarketSnapshot: Equatable, Sendable {
    let currentQuotes: [SpotPair: SpotQuote]
    let monthly: MonthlyDataset?

    init(currentQuotes: [SpotQuote], monthly: MonthlyDataset? = nil) {
        var quotesByPair: [SpotPair: SpotQuote] = [:]
        for quote in currentQuotes {
            if let existing = quotesByPair[quote.id], existing.sourceUpdatedAt > quote.sourceUpdatedAt {
                continue
            }
            quotesByPair[quote.id] = quote
        }
        self.currentQuotes = quotesByPair
        self.monthly = monthly
    }

    init(currentQuotes: [SpotPair: SpotQuote], monthly: MonthlyDataset? = nil) {
        self.currentQuotes = currentQuotes
        self.monthly = monthly
    }

    func quote(for metal: MarketMetal, currency: MarketCurrency) -> SpotQuote? {
        currentQuotes[SpotPair(metal: metal, currency: currency)]
    }
}

nonisolated enum PortfolioAssetValuationStatus: Equatable, Sendable {
    case valued
    case invalidQuantity
    case missingMetal
    case missingWeight
    case invalidWeight
    case missingPurity
    case invalidPurity
    case missingEURQuote
}

nonisolated struct AssetValuation: Equatable, Identifiable, Sendable {
    let assetID: UUID
    let name: String
    let categoryID: String
    let metal: MarketMetal?
    let quantity: Int
    let fineWeightGrams: Decimal?
    let estimatedValueEUR: Decimal?
    let purchaseCost: Decimal?
    let purchaseCurrency: MarketCurrency?
    let currentValueInPurchaseCurrency: Decimal?
    let purchaseCostEUR: Decimal?
    let gainInPurchaseCurrency: Decimal?
    let gainEUR: Decimal?
    let gainPercentage: Decimal?
    let status: PortfolioAssetValuationStatus

    var id: UUID { assetID }
}

nonisolated struct MetalValuation: Equatable, Identifiable, Sendable {
    let metal: MarketMetal
    let fineWeightGrams: Decimal
    let estimatedValueEUR: Decimal?
    let sharePercentage: Decimal?
    let recordCount: Int
    let objectCount: Int

    var id: MarketMetal { metal }
}

nonisolated struct CategoryValuation: Equatable, Identifiable, Sendable {
    let categoryID: String
    let estimatedValueEUR: Decimal?
    let sharePercentage: Decimal?
    let recordCount: Int
    let objectCount: Int

    var id: String { categoryID }
}

nonisolated struct PortfolioCoverage: Equatable, Sendable {
    let totalRecordCount: Int
    let valuedRecordCount: Int
    let performanceRecordCount: Int
    let totalObjectCount: Int
    let valuedObjectCount: Int

    var valuationPercentage: Decimal? {
        Self.percentage(part: valuedRecordCount, whole: totalRecordCount)
    }

    var performancePercentage: Decimal? {
        Self.percentage(part: performanceRecordCount, whole: totalRecordCount)
    }

    private static func percentage(part: Int, whole: Int) -> Decimal? {
        guard whole > 0 else { return nil }
        return Decimal(part) / Decimal(whole) * 100
    }
}

nonisolated struct PortfolioHistoryPoint: Equatable, Identifiable, Sendable {
    let date: Date
    let valueEUR: Decimal
    let valuedRecordCount: Int
    let totalHeldRecordCount: Int
    let isCurrent: Bool

    var id: Date { date }
}

nonisolated struct PortfolioValuation: Equatable, Sendable {
    let totalEstimatedValueEUR: Decimal
    let totalPurchaseCostEUR: Decimal?
    let totalGainEUR: Decimal?
    let gainPercentage: Decimal?
    let assetValuations: [AssetValuation]
    let metals: [MetalValuation]
    let categories: [CategoryValuation]
    let coverage: PortfolioCoverage
    let history: [PortfolioHistoryPoint]
    let historyUsesUnknownPurchaseDates: Bool
}

nonisolated struct PortfolioValuationEngine: Sendable {
    init() {}

    static func requiredSpotPairs(for assets: [PortfolioAssetSnapshot]) -> Set<SpotPair> {
        var pairs: Set<SpotPair> = []
        for asset in assets {
            guard let metal = asset.metal else { continue }
            pairs.insert(SpotPair(metal: metal, currency: .eur))
            if let purchaseCurrency = asset.purchaseCurrency {
                pairs.insert(SpotPair(metal: metal, currency: purchaseCurrency))
            }
        }
        return pairs
    }

    func valuate(
        assets: [PortfolioAssetSnapshot],
        market: PortfolioMarketSnapshot,
        historyMonths: Int = 12,
        asOf: Date = Date()
    ) -> PortfolioValuation {
        let assetValuations = assets.map { valuate(asset: $0, market: market) }
        let totalValue = assetValuations.compactMap(\.estimatedValueEUR).sum
        let performanceItems = assetValuations.filter { $0.gainEUR != nil && $0.purchaseCostEUR != nil }
        let totalCost = performanceItems.isEmpty ? nil : performanceItems.compactMap(\.purchaseCostEUR).sum
        let totalGain = performanceItems.isEmpty ? nil : performanceItems.compactMap(\.gainEUR).sum
        let gainPercentage: Decimal?
        if let totalCost, totalCost != 0, let totalGain {
            gainPercentage = totalGain / totalCost * 100
        } else {
            gainPercentage = nil
        }
        let coverage = PortfolioCoverage(
            totalRecordCount: assets.count,
            valuedRecordCount: assetValuations.count(where: { $0.estimatedValueEUR != nil }),
            performanceRecordCount: performanceItems.count,
            totalObjectCount: assets.map(\.validObjectCount).sum,
            valuedObjectCount: assetValuations
                .filter { $0.estimatedValueEUR != nil }
                .map { max(0, $0.quantity) }
                .sum
        )
        let history = history(
            assets: assets,
            currentValuations: assetValuations,
            market: market,
            requestedPointCount: historyMonths,
            asOf: asOf
        )

        return PortfolioValuation(
            totalEstimatedValueEUR: totalValue,
            totalPurchaseCostEUR: totalCost,
            totalGainEUR: totalGain,
            gainPercentage: gainPercentage,
            assetValuations: assetValuations,
            metals: metalBreakdowns(assets: assets, valuations: assetValuations, totalValue: totalValue),
            categories: categoryBreakdowns(assets: assets, valuations: assetValuations, totalValue: totalValue),
            coverage: coverage,
            history: history,
            historyUsesUnknownPurchaseDates: !history.isEmpty && assets.contains(where: { $0.purchaseDate == nil })
        )
    }

    private func valuate(
        asset: PortfolioAssetSnapshot,
        market: PortfolioMarketSnapshot
    ) -> AssetValuation {
        let content = fineMetalContent(of: asset)
        let fineWeight = content.fineWeight
        let eurQuote = asset.metal.flatMap { market.quote(for: $0, currency: .eur) }
        let valueEUR: Decimal?
        let status: PortfolioAssetValuationStatus

        if let issue = content.issue {
            valueEUR = nil
            status = issue
        } else if let fineWeight, let eurQuote {
            valueEUR = fineWeight * eurQuote.price / eurQuote.unit.grams
            status = .valued
        } else {
            valueEUR = nil
            status = .missingEURQuote
        }

        let performance = performance(
            asset: asset,
            fineWeight: fineWeight,
            valueEUR: valueEUR,
            market: market
        )

        return AssetValuation(
            assetID: asset.id,
            name: asset.name,
            categoryID: asset.categoryID,
            metal: asset.metal,
            quantity: asset.quantity,
            fineWeightGrams: fineWeight,
            estimatedValueEUR: valueEUR,
            purchaseCost: asset.purchaseCost,
            purchaseCurrency: asset.purchaseCurrency,
            currentValueInPurchaseCurrency: performance?.currentValue,
            purchaseCostEUR: performance?.costEUR,
            gainInPurchaseCurrency: performance?.gain,
            gainEUR: performance?.gainEUR,
            gainPercentage: performance?.gainPercentage,
            status: status
        )
    }

    private func performance(
        asset: PortfolioAssetSnapshot,
        fineWeight: Decimal?,
        valueEUR: Decimal?,
        market: PortfolioMarketSnapshot
    ) -> Performance? {
        guard let metal = asset.metal,
              let fineWeight,
              let valueEUR,
              let cost = asset.purchaseCost,
              cost >= 0,
              let currency = asset.purchaseCurrency
        else {
            return nil
        }

        if currency == .eur {
            let gain = valueEUR - cost
            return Performance(
                currentValue: valueEUR,
                costEUR: cost,
                gain: gain,
                gainEUR: gain,
                gainPercentage: cost == 0 ? nil : gain / cost * 100
            )
        }

        guard let currencyQuote = market.quote(for: metal, currency: currency),
              currencyQuote.price > 0,
              let eurQuote = market.quote(for: metal, currency: .eur)
        else {
            return nil
        }
        let currentValue = fineWeight * currencyQuote.price / currencyQuote.unit.grams
        let gain = currentValue - cost
        let euroPerPurchaseCurrency: Decimal
        if eurQuote.unit == currencyQuote.unit {
            euroPerPurchaseCurrency = eurQuote.price / currencyQuote.price
        } else {
            euroPerPurchaseCurrency = eurQuote.price * currencyQuote.unit.grams
                / (currencyQuote.price * eurQuote.unit.grams)
        }
        return Performance(
            currentValue: currentValue,
            costEUR: cost * euroPerPurchaseCurrency,
            gain: gain,
            gainEUR: gain * euroPerPurchaseCurrency,
            gainPercentage: cost == 0 ? nil : gain / cost * 100
        )
    }

    private func fineMetalContent(of asset: PortfolioAssetSnapshot) -> FineMetalContent {
        guard asset.quantity > 0 else {
            return FineMetalContent(issue: .invalidQuantity)
        }
        guard asset.metal != nil else {
            return FineMetalContent(issue: .missingMetal)
        }
        guard let grossWeight = asset.grossWeightGrams else {
            return FineMetalContent(issue: .missingWeight)
        }
        guard grossWeight > 0 else {
            return FineMetalContent(issue: .invalidWeight)
        }

        let purity: Decimal
        if let fineness = asset.finenessPermille {
            guard fineness > 0, fineness <= 1_000 else {
                return FineMetalContent(issue: .invalidPurity)
            }
            purity = fineness / 1_000
        } else if let karat = asset.metalKarat {
            guard karat > 0, karat <= 24 else {
                return FineMetalContent(issue: .invalidPurity)
            }
            purity = karat / 24
        } else {
            return FineMetalContent(issue: .missingPurity)
        }

        return FineMetalContent(fineWeight: Decimal(asset.quantity) * grossWeight * purity)
    }

    private func metalBreakdowns(
        assets: [PortfolioAssetSnapshot],
        valuations: [AssetValuation],
        totalValue: Decimal
    ) -> [MetalValuation] {
        MarketMetal.allCases.compactMap { metal in
            let matchingAssets = assets.filter { $0.metal == metal }
            guard !matchingAssets.isEmpty else { return nil }
            let matchingValuations = valuations.filter { $0.metal == metal }
            let values = matchingValuations.compactMap(\.estimatedValueEUR)
            let value = values.isEmpty ? nil : values.sum
            return MetalValuation(
                metal: metal,
                fineWeightGrams: matchingValuations.compactMap(\.fineWeightGrams).sum,
                estimatedValueEUR: value,
                sharePercentage: value.flatMap { totalValue > 0 ? $0 / totalValue * 100 : nil },
                recordCount: matchingAssets.count,
                objectCount: matchingAssets.map(\.validObjectCount).sum
            )
        }
    }

    private func categoryBreakdowns(
        assets: [PortfolioAssetSnapshot],
        valuations: [AssetValuation],
        totalValue: Decimal
    ) -> [CategoryValuation] {
        let categoryIDs = Set(assets.map(\.categoryID))
        return categoryIDs.map { categoryID in
            let matchingAssets = assets.filter { $0.categoryID == categoryID }
            let values = valuations
                .filter { $0.categoryID == categoryID }
                .compactMap(\.estimatedValueEUR)
            let value = values.isEmpty ? nil : values.sum
            return CategoryValuation(
                categoryID: categoryID,
                estimatedValueEUR: value,
                sharePercentage: value.flatMap { totalValue > 0 ? $0 / totalValue * 100 : nil },
                recordCount: matchingAssets.count,
                objectCount: matchingAssets.map(\.validObjectCount).sum
            )
        }
        .sorted { lhs, rhs in
            let lhsValue = lhs.estimatedValueEUR ?? -1
            let rhsValue = rhs.estimatedValueEUR ?? -1
            return lhsValue == rhsValue ? lhs.categoryID < rhs.categoryID : lhsValue > rhsValue
        }
    }

    private func history(
        assets: [PortfolioAssetSnapshot],
        currentValuations: [AssetValuation],
        market: PortfolioMarketSnapshot,
        requestedPointCount: Int,
        asOf: Date
    ) -> [PortfolioHistoryPoint] {
        guard requestedPointCount > 0, !assets.isEmpty else { return [] }
        var points: [PortfolioHistoryPoint] = []
        let calendar = Self.utcCalendar

        if requestedPointCount > 1, let monthly = market.monthly {
            let currentMonth = Self.monthIdentifier(for: asOf, calendar: calendar)
            let relevantMetals = Set(assets.compactMap(\.metal))
            let availableMonths = Set(monthly.series
                .filter { relevantMetals.contains($0.metal) }
                .flatMap(\.observations)
                .map(\.month))
                .filter { $0 < currentMonth }
                .sorted()
                .suffix(requestedPointCount - 1)

            for month in availableMonths {
                guard let date = Self.endOfMonth(month, calendar: calendar) else { continue }
                let heldAssets = assets.filter { $0.purchaseDate.map { $0 <= date } ?? true }
                let values = heldAssets.compactMap { asset -> Decimal? in
                    let content = fineMetalContent(of: asset)
                    guard let fineWeight = content.fineWeight,
                          let metal = asset.metal,
                          let price = monthly.price(for: metal, currency: .eur, month: month)
                    else {
                        return nil
                    }
                    return fineWeight * price / monthly.unit.grams
                }
                guard !heldAssets.isEmpty, !values.isEmpty else { continue }
                points.append(PortfolioHistoryPoint(
                    date: date,
                    valueEUR: values.sum,
                    valuedRecordCount: values.count,
                    totalHeldRecordCount: heldAssets.count,
                    isCurrent: false
                ))
            }
        }

        let currentHeldAssetIDs = Set(
            assets
                .filter { $0.purchaseDate.map { $0 <= asOf } ?? true }
                .map(\.id)
        )
        let currentHeldCount = currentHeldAssetIDs.count
        let currentValues = currentValuations
            .filter { currentHeldAssetIDs.contains($0.assetID) }
            .compactMap(\.estimatedValueEUR)
        if currentHeldCount > 0, !currentValues.isEmpty {
            points.append(PortfolioHistoryPoint(
                date: asOf,
                valueEUR: currentValues.sum,
                valuedRecordCount: currentValues.count,
                totalHeldRecordCount: currentHeldCount,
                isCurrent: true
            ))
        }
        return points
    }

    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func monthIdentifier(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }

    private static func endOfMonth(_ identifier: String, calendar: Calendar) -> Date? {
        let parts = identifier.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              (1...12).contains(month),
              let start = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: start)
        else {
            return nil
        }
        return calendar.date(byAdding: .second, value: -1, to: nextMonth)
    }
}

private nonisolated struct FineMetalContent {
    let fineWeight: Decimal?
    let issue: PortfolioAssetValuationStatus?

    init(fineWeight: Decimal? = nil, issue: PortfolioAssetValuationStatus? = nil) {
        self.fineWeight = fineWeight
        self.issue = issue
    }
}

private nonisolated struct Performance {
    let currentValue: Decimal
    let costEUR: Decimal
    let gain: Decimal
    let gainEUR: Decimal
    let gainPercentage: Decimal?
}

private nonisolated extension PortfolioAssetSnapshot {
    var validObjectCount: Int { max(0, quantity) }
}

private nonisolated extension Sequence where Element == Decimal {
    var sum: Decimal { reduce(0, +) }
}

private nonisolated extension Sequence where Element == Int {
    var sum: Int { reduce(0, +) }
}
