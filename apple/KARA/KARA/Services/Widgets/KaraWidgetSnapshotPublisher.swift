import Foundation
import WidgetKit

nonisolated struct KaraWidgetSnapshotPublicationInput: Equatable, Sendable {
    let generatedAt: Date
    let quotes: [KaraWidgetQuote]
    let portfolio: KaraWidgetPortfolio?
    let disclosure: KaraWidgetDisclosure
    let preservesExistingQuotes: Bool

    init(
        quotes: [MarketMetal: SpotQuote],
        valuation: PortfolioValuation,
        valuationAsOf: Date,
        hidesSensitiveValues: Bool,
        preservesExistingQuotes: Bool = true
    ) {
        let widgetQuotes: [KaraWidgetQuote] = MarketMetal.allCases.compactMap { metal in
            guard let quote = quotes[metal],
                  quote.price > 0,
                  quote.unit.grams > 0
            else {
                return nil
            }

            return KaraWidgetQuote(
                metal: metal.widgetMetal,
                ouncePrice: quote.price,
                unitGrams: quote.unit.grams,
                sourceUpdatedAt: quote.sourceUpdatedAt
            )
        }
        self.quotes = widgetQuotes
        generatedAt = widgetQuotes.map(\.sourceUpdatedAt).min() ?? valuationAsOf
        self.preservesExistingQuotes = preservesExistingQuotes

        if hidesSensitiveValues {
            portfolio = nil
            disclosure = .hidden
        } else if valuation.coverage.valuedRecordCount == 0 {
            portfolio = nil
            disclosure = .unavailable
        } else {
            let currentHistoryDate = widgetQuotes
                .map(\.sourceUpdatedAt)
                .min()
                ?? valuationAsOf

            portfolio = KaraWidgetPortfolio(
                totalValueEUR: valuation.totalEstimatedValueEUR,
                totalGainEUR: valuation.totalGainEUR,
                gainPercentage: valuation.gainPercentage,
                valuedRecordCount: valuation.coverage.valuedRecordCount,
                totalRecordCount: valuation.coverage.totalRecordCount,
                objectCount: valuation.coverage.totalObjectCount,
                history: Self.widgetHistory(
                    from: valuation.history,
                    currentHistoryDate: currentHistoryDate
                )
            )
            disclosure = .visible
        }
    }

    fileprivate func snapshot(
        preservingQuotesFrom existingSnapshot: KaraWidgetSnapshot?
    ) -> KaraWidgetSnapshot {
        KaraWidgetSnapshot(
            generatedAt: preservesExistingQuotes && quotes.isEmpty
                ? existingSnapshot?.generatedAt ?? generatedAt
                : generatedAt,
            quotes: preservesExistingQuotes && quotes.isEmpty
                ? existingSnapshot?.quotes ?? []
                : quotes,
            portfolio: portfolio,
            disclosure: disclosure
        )
    }

    private static func widgetHistory(
        from history: [PortfolioHistoryPoint],
        currentHistoryDate: Date
    ) -> [KaraWidgetHistoryPoint] {
        var valuesByDate: [Date: Decimal] = [:]

        for point in history where point.valuedRecordCount > 0 {
            let date = point.isCurrent ? currentHistoryDate : point.date
            valuesByDate[date] = point.valueEUR
        }

        return valuesByDate
            .map { date, value in
                KaraWidgetHistoryPoint(date: date, valueEUR: value)
            }
            .sorted { $0.date < $1.date }
    }
}

@MainActor
enum KaraWidgetSnapshotPublisher {
    static let widgetKind = "com.karaprivate.KARA.widget.panorama"

    @discardableResult
    static func publish(_ input: KaraWidgetSnapshotPublicationInput) -> Bool {
        guard let store = try? KaraWidgetSnapshotStore() else { return false }

        let existingSnapshot: KaraWidgetSnapshot?
        do {
            existingSnapshot = try store.read()
        } catch {
            existingSnapshot = nil
        }

        // The foreground app may briefly publish before its market store has
        // completed loading, so it can preserve an existing quote set. The
        // background refresh explicitly disables that behavior: a failed
        // refresh must not make an old quote look freshly published.
        guard !input.quotes.isEmpty
            || (input.preservesExistingQuotes && existingSnapshot != nil)
            || input.disclosure == .hidden
            || input.disclosure == .unavailable
        else {
            return false
        }

        let snapshot = input.snapshot(preservingQuotesFrom: existingSnapshot)
        guard existingSnapshot?.hasSameContent(as: snapshot) != true else {
            return true
        }

        do {
            if input.disclosure == .hidden {
                // Remove first so a crash or failed replacement cannot leave a
                // visible portfolio behind after the user enabled masking.
                try store.remove()
            }
            try store.write(snapshot)
        } catch {
            if input.disclosure == .hidden {
                try? store.remove()
            }
            return false
        }

        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
        return true
    }
}

private nonisolated extension MarketMetal {
    var widgetMetal: KaraWidgetMetal {
        switch self {
        case .gold:
            .gold
        case .silver:
            .silver
        case .platinum:
            .platinum
        case .palladium:
            .palladium
        }
    }
}
