import Foundation

/// Anonymous valuation inputs only; no asset names, identifiers or documents.
nonisolated struct KaraWidgetHolding: Codable, Equatable, Sendable {
    let metal: KaraWidgetMetal
    let fineWeightGrams: Decimal
    let purchaseCost: Decimal?
    let purchaseCurrency: String?
}

nonisolated struct KaraWidgetRefreshCoverage: Codable, Equatable, Sendable {
    let totalRecordCount: Int
    let objectCount: Int
}

nonisolated extension KaraWidgetSnapshot {
    func refreshing(with market: [KaraWidgetMarketQuote]) -> KaraWidgetSnapshot {
        var market = market.filter { $0.price.isFinite && $0.price > 0 && $0.unitGrams.isFinite && $0.unitGrams > 0 }
        // A foreground publication may already contain newer EUR quotes than the extension cache.
        for quote in self.quotes {
            let current = KaraWidgetMarketQuote(metal: quote.metal, currency: "EUR", price: quote.ouncePrice,
                unitGrams: quote.unitGrams, sourceUpdatedAt: quote.sourceUpdatedAt)
            if let index = market.firstIndex(where: { $0.metal == quote.metal && $0.currency == "EUR" }) {
                if quote.sourceUpdatedAt > market[index].sourceUpdatedAt { market[index] = current }
            } else {
                market.append(current)
            }
        }
        let quotes = KaraWidgetMetal.allCases.compactMap { metal -> KaraWidgetQuote? in
            let old = quote(for: metal)
            guard let fresh = market.first(where: { $0.metal == metal && $0.currency == "EUR" }),
                  old == nil || fresh.sourceUpdatedAt >= old!.sourceUpdatedAt else { return old }
            return KaraWidgetQuote(metal: metal, ouncePrice: fresh.price,
                unitGrams: fresh.unitGrams, sourceUpdatedAt: fresh.sourceUpdatedAt)
        }
        var refreshedPortfolio = portfolio
        var asOf = generatedAt
        var disclosure = disclosure
        if disclosure != .hidden, let holdings, !holdings.isEmpty,
           let totalRecords = refreshCoverage?.totalRecordCount ?? portfolio?.totalRecordCount,
           let objects = refreshCoverage?.objectCount ?? portfolio?.objectCount,
           let valuation = revalue(holdings, market: market), portfolio == nil || valuation.date >= generatedAt {
            let history = Array((portfolio?.history ?? []).dropLast()) + [
                KaraWidgetHistoryPoint(date: valuation.date, valueEUR: valuation.value)
            ]
            refreshedPortfolio = KaraWidgetPortfolio(totalValueEUR: valuation.value,
                totalGainEUR: valuation.gain, gainPercentage: valuation.percentage,
                valuedRecordCount: holdings.count, totalRecordCount: totalRecords,
                objectCount: objects, history: history)
            asOf = valuation.date
            disclosure = .visible
        }
        return KaraWidgetSnapshot(generatedAt: asOf, quotes: quotes,
            portfolio: disclosure == .visible ? refreshedPortfolio : nil,
            disclosure: disclosure, holdings: holdings, refreshCoverage: refreshCoverage)
    }

    private func revalue(_ holdings: [KaraWidgetHolding], market: [KaraWidgetMarketQuote])
        -> (value: Decimal, gain: Decimal?, percentage: Decimal?, date: Date)? {
        var total: Decimal = 0
        var gain: Decimal = 0
        var cost: Decimal = 0
        var performanceCount = 0
        var dates: [Date] = []
        for holding in holdings {
            guard holding.fineWeightGrams.isFinite, holding.fineWeightGrams > 0,
                  let euro = market.first(where: { $0.metal == holding.metal && $0.currency == "EUR" })
            else { return nil }
            let value = holding.fineWeightGrams * euro.price / euro.unitGrams
            total += value
            dates.append(euro.sourceUpdatedAt)
            if let purchaseCost = holding.purchaseCost, let currency = holding.purchaseCurrency {
                guard purchaseCost.isFinite, purchaseCost >= 0,
                      let foreign = market.first(where: { $0.metal == holding.metal && $0.currency == currency })
                else { return nil }
                let exchangeRate = euro.unitGrams == foreign.unitGrams
                    ? euro.price / foreign.price
                    : euro.price * foreign.unitGrams / (foreign.price * euro.unitGrams)
                let costEUR = purchaseCost * exchangeRate
                gain += value - costEUR
                cost += costEUR
                performanceCount += 1
                dates.append(foreign.sourceUpdatedAt)
            }
        }
        guard total.isFinite, gain.isFinite, cost.isFinite, let date = dates.min() else { return nil }
        return (total, performanceCount > 0 ? gain : nil,
            performanceCount > 0 && cost > 0 ? gain / cost * 100 : nil, date)
    }
}
