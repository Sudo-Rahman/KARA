import Foundation
import WidgetKit

nonisolated struct KaraWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: KaraWidgetSnapshot?
    let viewMode: KaraWidgetViewMode
    let favoriteMetal: KaraWidgetFavoriteMetal
    let isPlaceholder: Bool

    var selectedQuote: KaraWidgetQuote? {
        snapshot?.quote(for: favoriteMetal.sharedValue)
    }

    static let gallery = KaraWidgetEntry(
        date: .now,
        snapshot: .galleryExample,
        viewMode: .market,
        favoriteMetal: .gold,
        isPlaceholder: false
    )

    static let galleryPortfolio = KaraWidgetEntry(
        date: .now,
        snapshot: .galleryExample,
        viewMode: .portfolio,
        favoriteMetal: .gold,
        isPlaceholder: false
    )

    static let galleryHidden = KaraWidgetEntry(
        date: .now,
        snapshot: .galleryHidden,
        viewMode: .portfolio,
        favoriteMetal: .gold,
        isPlaceholder: false
    )
}

nonisolated struct KaraWidgetTimelineProvider: AppIntentTimelineProvider {
    private let store: KaraWidgetSnapshotStore?

    init(store: KaraWidgetSnapshotStore? = try? KaraWidgetSnapshotStore()) {
        self.store = store
    }

    func placeholder(in context: Context) -> KaraWidgetEntry {
        KaraWidgetEntry(
            date: .now,
            snapshot: .galleryExample,
            viewMode: .market,
            favoriteMetal: .gold,
            isPlaceholder: true
        )
    }

    func snapshot(
        for configuration: KaraWidgetConfigurationIntent,
        in context: Context
    ) async -> KaraWidgetEntry {
        makeEntry(
            configuration: configuration,
            galleryFallback: context.isPreview
        )
    }

    func timeline(
        for configuration: KaraWidgetConfigurationIntent,
        in context: Context
    ) async -> Timeline<KaraWidgetEntry> {
        let entry = makeEntry(configuration: configuration, galleryFallback: false)
        let nextRead = Calendar.current.date(
            byAdding: .minute,
            value: 30,
            to: entry.date
        ) ?? entry.date.addingTimeInterval(30 * 60)
        return Timeline(entries: [entry], policy: .after(nextRead))
    }

    func recommendations() -> [AppIntentRecommendation<KaraWidgetConfigurationIntent>] {
        [
            AppIntentRecommendation(
                intent: KaraWidgetConfigurationIntent(
                    viewMode: .market,
                    favoriteMetal: .gold
                ),
                description: LocalizedStringResource(
                    "widget.recommendation.market"
                )
            ),
            AppIntentRecommendation(
                intent: KaraWidgetConfigurationIntent(viewMode: .portfolio),
                description: LocalizedStringResource(
                    "widget.recommendation.portfolio"
                )
            ),
        ]
    }

    private func makeEntry(
        configuration: KaraWidgetConfigurationIntent,
        galleryFallback: Bool
    ) -> KaraWidgetEntry {
        let storedSnapshot: KaraWidgetSnapshot?
        if let store {
            storedSnapshot = try? store.read()
        } else {
            storedSnapshot = nil
        }

        return KaraWidgetEntry(
            date: .now,
            snapshot: storedSnapshot ?? (galleryFallback ? .galleryExample : nil),
            viewMode: configuration.viewMode,
            favoriteMetal: configuration.favoriteMetal,
            isPlaceholder: false
        )
    }
}

private nonisolated extension KaraWidgetSnapshot {
    static var galleryExample: KaraWidgetSnapshot {
        let now = Date.now
        let quoteDate = now.addingTimeInterval(-12 * 60)
        let calendar = Calendar(identifier: .gregorian)
        let historyValues: [Decimal] = [
            11_755, 12_140, 12_980, 13_460, 14_920, 16_880, 17_569,
        ]
        let history = historyValues.enumerated().map { index, value in
            KaraWidgetHistoryPoint(
                date: calendar.date(
                    byAdding: .month,
                    value: index - historyValues.count + 1,
                    to: now
                ) ?? now,
                valueEUR: value
            )
        }

        return KaraWidgetSnapshot(
            generatedAt: now,
            quotes: [
                KaraWidgetQuote(
                    metal: .gold,
                    ouncePrice: 2_999.42,
                    unitGrams: 31.1034768,
                    sourceUpdatedAt: quoteDate
                ),
                KaraWidgetQuote(
                    metal: .silver,
                    ouncePrice: 31.17,
                    unitGrams: 31.1034768,
                    sourceUpdatedAt: quoteDate
                ),
                KaraWidgetQuote(
                    metal: .platinum,
                    ouncePrice: 988.90,
                    unitGrams: 31.1034768,
                    sourceUpdatedAt: quoteDate
                ),
                KaraWidgetQuote(
                    metal: .palladium,
                    ouncePrice: 956.35,
                    unitGrams: 31.1034768,
                    sourceUpdatedAt: quoteDate
                ),
            ],
            portfolio: KaraWidgetPortfolio(
                totalValueEUR: 17_569,
                totalGainEUR: 5_814,
                gainPercentage: 49.5,
                valuedRecordCount: 5,
                totalRecordCount: 5,
                objectCount: 8,
                history: history
            ),
            disclosure: .visible
        )
    }

    static var galleryHidden: KaraWidgetSnapshot {
        KaraWidgetSnapshot(
            generatedAt: .now,
            quotes: galleryExample.quotes,
            portfolio: nil,
            disclosure: .hidden
        )
    }
}
