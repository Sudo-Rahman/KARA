import SwiftUI
import WidgetKit

struct KaraWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let entry: KaraWidgetEntry

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                KaraSmallWidgetView(
                    entry: entry,
                    style: style,
                    compactAccessibility: compactAccessibility
                )
            case .systemMedium:
                KaraMediumWidgetView(
                    entry: entry,
                    style: style,
                    compactAccessibility: compactAccessibility
                )
            case .systemLarge:
                KaraLargeWidgetView(
                    entry: entry,
                    style: style,
                    compactAccessibility: compactAccessibility
                )
            default:
                KaraSmallWidgetView(
                    entry: entry,
                    style: style,
                    compactAccessibility: compactAccessibility
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(style.ink)
        .containerBackground(for: .widget) {
            KaraWidgetContainerBackground()
        }
        .redacted(reason: entry.isPlaceholder ? .placeholder : [])
    }

    private var style: KaraWidgetStyle {
        KaraWidgetStyle(
            isFullColor: renderingMode == .fullColor,
            increasedContrast: colorSchemeContrast == .increased
        )
    }

    private var compactAccessibility: Bool {
        dynamicTypeSize.isAccessibilitySize
            || dynamicTypeSize == .xxLarge
            || dynamicTypeSize == .xxxLarge
    }
}

private struct KaraSmallWidgetView: View {
    let entry: KaraWidgetEntry
    let style: KaraWidgetStyle
    let compactAccessibility: Bool

    var body: some View {
        switch entry.viewMode {
        case .market:
            KaraSmallMarketWidgetView(
                entry: entry,
                style: style,
                compactAccessibility: compactAccessibility
            )
        case .portfolio:
            KaraSmallPortfolioWidgetView(
                entry: entry,
                style: style,
                compactAccessibility: compactAccessibility
            )
        }
    }
}

private struct KaraSmallMarketWidgetView: View {
    let entry: KaraWidgetEntry
    let style: KaraWidgetStyle
    let compactAccessibility: Bool

    var body: some View {
        if let quote = entry.selectedQuote {
            VStack(alignment: .leading, spacing: 0) {
                KaraWidgetHeader(style: style)

                Spacer(minLength: 13)

                HStack(alignment: .bottom, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.favoriteMetal.localizedName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(style.ink)
                            .lineLimit(1)

                        Text("€/g")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(style.muted)
                    }

                    Spacer(minLength: 2)

                    Text(KaraWidgetFormatters.number(
                        quote.pricePerGram,
                        maximumFractionDigits: 2
                    ))
                    .font(.karaWidgetDisplay(size: 32, relativeTo: .title))
                    .foregroundStyle(style.metal(entry.favoriteMetal))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                }

                Spacer(minLength: 6)

                KaraWidgetFooter(
                    leading: karaSmallWidgetMarketLabel(entry.favoriteMetal),
                    date: compactAccessibility ? nil : quote.sourceUpdatedAt,
                    style: style
                )
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(entry.favoriteMetal.localizedName))
            .accessibilityValue(
                Text(verbatim: karaMarketAccessibilityValue(quote))
            )
        } else {
            KaraWidgetEmptyState(
                symbol: "chart.line.downtrend.xyaxis",
                title: "widget.market.unavailable",
                detail: "widget.empty.open-app",
                style: style
            )
        }
    }
}

private struct KaraSmallPortfolioWidgetView: View {
    let entry: KaraWidgetEntry
    let style: KaraWidgetStyle
    let compactAccessibility: Bool

    var body: some View {
        switch entry.snapshot?.disclosure ?? .unavailable {
        case .visible:
            if let portfolio = entry.snapshot?.portfolio {
                visible(portfolio)
            } else {
                unavailable
            }
        case .hidden:
            state(
                symbol: "eye.slash.fill",
                title: "widget.portfolio.hidden",
                detail: "widget.portfolio.hidden-detail"
            )
        case .unavailable:
            unavailable
        }
    }

    private func visible(_ portfolio: KaraWidgetPortfolio) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            KaraWidgetHeader(style: style)

            Spacer(minLength: 8)

            Text("widget.portfolio.title")
                .font(.caption.weight(.medium))
                .foregroundStyle(style.muted)
                .lineLimit(1)

            Text(KaraWidgetFormatters.currency(portfolio.totalValueEUR))
                .font(.karaWidgetDisplay(size: 27, relativeTo: .title))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.58)

            if !compactAccessibility,
               let gain = portfolio.totalGainEUR {
                HStack(spacing: 6) {
                    Text(KaraWidgetFormatters.currency(
                        gain,
                        showsPositiveSign: true
                    ))
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(style.performance(gain))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        style.performance(gain).opacity(0.14),
                        in: .capsule
                    )

                    if let percentage = portfolio.gainPercentage {
                        Text(KaraWidgetFormatters.percentage(percentage))
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(style.performance(percentage))
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 3)

            KaraWidgetFooter(
                leading: karaPortfolioRecordSummary(portfolio),
                date: compactAccessibility ? nil : entry.snapshot?.generatedAt,
                style: style
            )
        }
        .privacySensitive()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("widget.portfolio.title"))
        .accessibilityValue(
            Text(verbatim: karaPortfolioAccessibilityValue(portfolio))
        )
    }

    private var unavailable: some View {
        state(
            symbol: "lock.shield.fill",
            title: "widget.portfolio.unavailable",
            detail: "widget.empty.open-app"
        )
    }

    private func state(
        symbol: String,
        title: LocalizedStringKey,
        detail: LocalizedStringKey
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            KaraWidgetHeader(style: style)
            Spacer(minLength: 8)
            KaraWidgetEmptyState(
                symbol: symbol,
                title: title,
                detail: detail,
                style: style
            )
            Spacer(minLength: 0)
        }
    }
}

private struct KaraMediumWidgetView: View {
    let entry: KaraWidgetEntry
    let style: KaraWidgetStyle
    let compactAccessibility: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            KaraWidgetHeader(style: style)

            Spacer(minLength: 9)

            HStack(spacing: 14) {
                KaraPortfolioMetrics(
                    snapshot: entry.snapshot,
                    style: style,
                    compactAccessibility: compactAccessibility
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                Rectangle()
                    .fill(style.divider)
                    .frame(width: 1)
                    .accessibilityHidden(true)

                KaraQuotesColumn(
                    quotes: entry.snapshot?.quotes ?? [],
                    style: style,
                    maximumRows: compactAccessibility ? 2 : 4
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
    }
}

private struct KaraLargeWidgetView: View {
    let entry: KaraWidgetEntry
    let style: KaraWidgetStyle
    let compactAccessibility: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            KaraWidgetHeader(style: style)
            portfolioFirst
        }
    }

    private var portfolioFirst: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 8)

            KaraPortfolioHero(
                snapshot: entry.snapshot,
                quoteCount: entry.snapshot?.quotes.count ?? 0,
                style: style,
                compactAccessibility: compactAccessibility
            )

            Spacer(minLength: 6)
            KaraWidgetDivider(style: style)
            Spacer(minLength: 5)

            if let portfolio = entry.snapshot?.portfolio,
               entry.snapshot?.disclosure == .visible,
               !compactAccessibility,
               portfolio.history.count >= 2 {
                KaraWidgetHistoryChart(
                    points: portfolio.history,
                    style: style
                )
                .frame(height: 92)
            } else {
                Spacer(minLength: 0)
            }

            Spacer(minLength: 5)
            KaraWidgetDivider(style: style)
            Spacer(minLength: 5)

            KaraQuotesStrip(
                quotes: entry.snapshot?.quotes ?? [],
                style: style,
                maximumRows: compactAccessibility ? 2 : 4
            )

            Spacer(minLength: 3)
            KaraWidgetFooter(
                leading: nil,
                date: compactAccessibility ? nil : entry.snapshot?.generatedAt,
                style: style,
                dateOnLeading: true
            )
        }
    }

}

private struct KaraWidgetHeader: View {
    let style: KaraWidgetStyle

    var body: some View {
        HStack(spacing: 8) {
            Text("KARA")
                .font(.karaWidgetDisplay(size: 13, relativeTo: .caption))
                .tracking(1.8)
                .foregroundStyle(style.gold)
                .widgetAccentable()
                .accessibilityLabel(Text("KARA"))

            Spacer(minLength: 4)

            KaraBullionMark(style: style)
        }
    }
}

private struct KaraBullionMark: View {
    let style: KaraWidgetStyle

    var body: some View {
        Canvas { context, size in
            let stroke = StrokeStyle(
                lineWidth: 1.55,
                lineCap: .round,
                lineJoin: .round
            )

            func bar(
                x: CGFloat,
                y: CGFloat,
                width: CGFloat,
                height: CGFloat
            ) -> Path {
                var path = Path()
                path.move(to: CGPoint(x: x + width * 0.20, y: y))
                path.addLine(to: CGPoint(x: x + width * 0.80, y: y))
                path.addLine(to: CGPoint(x: x + width, y: y + height))
                path.addLine(to: CGPoint(x: x, y: y + height))
                path.closeSubpath()
                return path
            }

            context.stroke(
                bar(x: 1, y: 10, width: 12, height: 7),
                with: .color(style.gold),
                style: stroke
            )
            context.stroke(
                bar(x: 15, y: 10, width: 12, height: 7),
                with: .color(style.gold),
                style: stroke
            )
            context.stroke(
                bar(x: 8, y: 2, width: 12, height: 7),
                with: .color(style.gold),
                style: stroke
            )
        }
        .frame(width: 28, height: 19)
        .widgetAccentable()
        .accessibilityHidden(true)
    }
}

private struct KaraPortfolioMetrics: View {
    let snapshot: KaraWidgetSnapshot?
    let style: KaraWidgetStyle
    let compactAccessibility: Bool

    var body: some View {
        switch snapshot?.disclosure ?? .unavailable {
        case .visible:
            if let portfolio = snapshot?.portfolio {
                visible(portfolio)
            } else {
                unavailable
            }
        case .hidden:
            hidden
        case .unavailable:
            unavailable
        }
    }

    private func visible(_ portfolio: KaraWidgetPortfolio) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("widget.portfolio.title")
                .font(.caption.weight(.medium))
                .foregroundStyle(style.muted)
                .lineLimit(1)

            Text(KaraWidgetFormatters.currency(portfolio.totalValueEUR))
                .font(.karaWidgetDisplay(size: 28, relativeTo: .title))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.60)

            if !compactAccessibility {
                KaraPortfolioGain(
                    portfolio: portfolio,
                    style: style,
                    compact: true
                )
            }

            Spacer(minLength: 0)

            Text(verbatim: karaPortfolioRecordSummary(portfolio))
                .font(.caption2.weight(.medium))
                .foregroundStyle(style.muted)
                .lineLimit(1)
        }
        .privacySensitive()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("widget.portfolio.title"))
        .accessibilityValue(
            Text(verbatim: karaPortfolioAccessibilityValue(portfolio))
        )
    }

    private var hidden: some View {
        KaraWidgetEmptyState(
            symbol: "eye.slash.fill",
            title: "widget.portfolio.hidden",
            detail: "widget.portfolio.hidden-detail",
            style: style
        )
    }

    private var unavailable: some View {
        KaraWidgetEmptyState(
            symbol: "lock.shield.fill",
            title: "widget.portfolio.unavailable",
            detail: "widget.empty.open-app",
            style: style
        )
    }
}

private struct KaraPortfolioGain: View {
    let portfolio: KaraWidgetPortfolio
    let style: KaraWidgetStyle
    let compact: Bool

    var body: some View {
        if let gain = portfolio.totalGainEUR {
            VStack(alignment: .leading, spacing: 3) {
                Text(KaraWidgetFormatters.currency(
                    gain,
                    showsPositiveSign: true
                ))
                .font(
                    compact
                        ? .caption2.weight(.semibold).monospacedDigit()
                        : .caption.weight(.semibold).monospacedDigit()
                )
                .foregroundStyle(style.performance(gain))
                .padding(.horizontal, compact ? 8 : 10)
                .padding(.vertical, compact ? 3 : 5)
                .background(style.performance(gain).opacity(0.14), in: .capsule)

                if let percentage = portfolio.gainPercentage {
                    Text(KaraWidgetFormatters.percentage(percentage))
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(style.performance(percentage))
                }
            }
        }
    }
}

private struct KaraPortfolioHero: View {
    let snapshot: KaraWidgetSnapshot?
    let quoteCount: Int
    let style: KaraWidgetStyle
    let compactAccessibility: Bool

    var body: some View {
        if snapshot?.disclosure == .visible,
           let portfolio = snapshot?.portfolio {
            HStack(alignment: .top, spacing: 15) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("widget.portfolio.title")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(style.muted)
                    Text(KaraWidgetFormatters.currency(portfolio.totalValueEUR))
                        .font(.karaWidgetDisplay(size: 30, relativeTo: .title))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)

                    if !compactAccessibility {
                        KaraPortfolioGain(
                            portfolio: portfolio,
                            style: style,
                            compact: true
                        )
                    }

                    Text(verbatim: karaPortfolioRecordSummary(portfolio))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(style.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle()
                    .fill(style.divider)
                    .frame(width: 1, height: 80)
                    .accessibilityHidden(true)

                KaraPortfolioCoverage(
                    portfolio: portfolio,
                    quoteCount: quoteCount,
                    style: style
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .privacySensitive()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("widget.portfolio.title"))
            .accessibilityValue(
                Text(verbatim: karaPortfolioAccessibilityValue(portfolio))
            )
        } else {
            KaraPortfolioMetrics(
                snapshot: snapshot,
                style: style,
                compactAccessibility: compactAccessibility
            )
        }
    }
}

private struct KaraPortfolioCoverage: View {
    let portfolio: KaraWidgetPortfolio
    let quoteCount: Int
    let style: KaraWidgetStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("widget.portfolio.coverage.title")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(style.muted)

            if let percentage = karaCoveragePercentage(portfolio) {
                Text(KaraWidgetFormatters.percentage(
                    percentage,
                    showsPositiveSign: false
                ))
                    .font(.karaWidgetDisplay(size: 30, relativeTo: .title))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }

            Text(verbatim: karaPortfolioMetalSummary(quoteCount))
                .font(.caption.weight(.medium))
                .foregroundStyle(style.muted)
                .lineLimit(2)
        }
    }
}

private struct KaraQuotesColumn: View {
    let quotes: [KaraWidgetQuote]
    let style: KaraWidgetStyle
    let maximumRows: Int

    var body: some View {
        let visibleQuotes = karaSortedQuotes(quotes)
            .prefix(maximumRows)

        if visibleQuotes.isEmpty {
            KaraWidgetEmptyState(
                symbol: "wifi.exclamationmark",
                title: "widget.market.unavailable",
                detail: "widget.empty.open-app",
                style: style
            )
        } else {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(visibleQuotes), id: \.id) { quote in
                    KaraQuoteRow(quote: quote, style: style)
                        .frame(maxHeight: .infinity)
                }
            }
        }
    }
}

private struct KaraQuotesStrip: View {
    let quotes: [KaraWidgetQuote]
    let style: KaraWidgetStyle
    let maximumRows: Int

    var body: some View {
        let visibleQuotes = Array(karaSortedQuotes(quotes).prefix(maximumRows))

        if visibleQuotes.isEmpty {
            KaraWidgetEmptyState(
                symbol: "wifi.exclamationmark",
                title: "widget.market.unavailable",
                detail: "widget.empty.open-app",
                style: style
            )
        } else {
            HStack(spacing: 0) {
                ForEach(Array(visibleQuotes.enumerated()), id: \.element.id) { index, quote in
                    if index > 0 {
                        KaraWidgetVerticalDivider(style: style)
                            .frame(height: 52)
                            .padding(.horizontal, 5)
                    }
                    KaraQuoteStripCell(quote: quote, style: style)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}

private struct KaraQuoteRow: View {
    let quote: KaraWidgetQuote
    let style: KaraWidgetStyle

    var body: some View {
        let metal = KaraWidgetFavoriteMetal(quote.metal)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Circle()
                    .fill(style.metal(metal))
                    .frame(width: 8, height: 8)

                Text(metal.symbol)
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundStyle(style.metal(metal))

                Text(metal.localizedName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(style.muted)
                    .lineLimit(1)

                Spacer(minLength: 4)

                Text(KaraWidgetFormatters.currency(
                    quote.pricePerGram,
                    maximumFractionDigits: 2
                ))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            }

        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(metal.localizedName))
        .accessibilityValue(
            Text(verbatim: karaQuoteAccessibilityValue(quote))
        )
    }
}

private struct KaraQuoteStripCell: View {
    let quote: KaraWidgetQuote
    let style: KaraWidgetStyle

    var body: some View {
        let metal = KaraWidgetFavoriteMetal(quote.metal)
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Circle()
                    .fill(style.metal(metal))
                    .frame(width: 8, height: 8)
                Text(metal.symbol)
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundStyle(style.metal(metal))
            }

            Text(metal.localizedName)
                .font(.caption2.weight(.medium))
                .foregroundStyle(style.muted)
                .lineLimit(1)

            Text(KaraWidgetFormatters.currency(
                quote.pricePerGram,
                maximumFractionDigits: 2
            ))
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .allowsTightening(true)
            .lineLimit(1)
            .minimumScaleFactor(0.62)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(metal.localizedName))
        .accessibilityValue(
            Text(verbatim: karaQuoteAccessibilityValue(quote))
        )
    }
}

private struct KaraWidgetHistoryChart: View {
    let points: [KaraWidgetHistoryPoint]
    let style: KaraWidgetStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("widget.portfolio.history")
                .font(.caption2.weight(.semibold))
                .tracking(0.55)
                .textCase(.uppercase)
                .foregroundStyle(style.gold)

            HStack(alignment: .top, spacing: 6) {
                KaraWidgetSparkline(points: points, style: style)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)

                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(karaHistoryAxisLabels, id: \.self) { label in
                        Text(label)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(style.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                            .frame(maxHeight: .infinity, alignment: .top)
                    }
                }
                .frame(width: 46, height: 60)
            }

            HStack(spacing: 0) {
                ForEach(karaHistoryMonthLabels(points), id: \.self) { label in
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(style.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.trailing, 46)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("widget.portfolio.history.accessibility"))
        .accessibilityValue(Text(verbatim: karaHistoryAccessibilityValue(points)))
        .privacySensitive()
    }
}

private struct KaraWidgetSparkline: View {
    let points: [KaraWidgetHistoryPoint]
    let style: KaraWidgetStyle

    var body: some View {
        GeometryReader { geometry in
            let coordinates = coordinates(in: geometry.size)

            ZStack {
                Path { path in
                    guard let first = coordinates.first,
                          let last = coordinates.last
                    else { return }
                    path.move(to: CGPoint(x: first.x, y: geometry.size.height))
                    path.addLine(to: first)
                    for point in coordinates.dropFirst() {
                        path.addLine(to: point)
                    }
                    path.addLine(to: CGPoint(x: last.x, y: geometry.size.height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [
                            style.gold.opacity(0.25),
                            style.gold.opacity(0.03),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Path { path in
                    guard let first = coordinates.first else { return }
                    path.move(to: first)
                    for point in coordinates.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(
                    style.gold,
                    style: StrokeStyle(
                        lineWidth: 2.4,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .widgetAccentable()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("widget.portfolio.history.accessibility"))
        .accessibilityValue(Text(verbatim: karaHistoryAccessibilityValue(points)))
        .privacySensitive()
    }

    private func coordinates(in size: CGSize) -> [CGPoint] {
        let values = points.map { NSDecimalNumber(decimal: $0.valueEUR).doubleValue }
        guard values.count >= 2,
              let minimum = values.min(),
              let maximum = values.max()
        else { return [] }

        let range = max(maximum - minimum, 1)
        let widthStep = size.width / CGFloat(values.count - 1)
        let verticalInset: CGFloat = 4
        let drawableHeight = max(size.height - verticalInset * 2, 1)

        return values.enumerated().map { index, value in
            let normalized = (value - minimum) / range
            return CGPoint(
                x: CGFloat(index) * widthStep,
                y: verticalInset + drawableHeight * (1 - CGFloat(normalized))
            )
        }
    }
}

private struct KaraWidgetFooter: View {
    let leading: String?
    let date: Date?
    let style: KaraWidgetStyle
    var dateOnLeading = false

    var body: some View {
        HStack(spacing: 5) {
            if dateOnLeading, let date {
                Text(date, format: .dateTime.hour().minute())
                    .monospacedDigit()
            } else if let leading {
                Text(verbatim: leading)
            }

            Spacer(minLength: 0)

            if !dateOnLeading, let date {
                Text(date, format: .dateTime.hour().minute())
                    .monospacedDigit()
            }
        }
        .font(.caption2)
        .foregroundStyle(style.muted)
        .lineLimit(1)
    }
}

private struct KaraWidgetDivider: View {
    let style: KaraWidgetStyle

    var body: some View {
        Rectangle()
            .fill(style.divider)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
}

private struct KaraWidgetVerticalDivider: View {
    let style: KaraWidgetStyle

    var body: some View {
        Rectangle()
            .fill(style.divider)
            .frame(width: 1)
            .accessibilityHidden(true)
    }
}

private struct KaraWidgetEmptyState: View {
    let symbol: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let style: KaraWidgetStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(style.gold)
                .widgetAccentable()
                .accessibilityHidden(true)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)

            Text(detail)
                .font(.caption2)
                .foregroundStyle(style.muted)
                .lineLimit(2)
        }
        .accessibilityElement(children: .combine)
    }
}

private func karaSortedQuotes(_ quotes: [KaraWidgetQuote]) -> [KaraWidgetQuote] {
    quotes.sorted {
        KaraWidgetMetal.allCases.firstIndex(of: $0.metal)
            ?? KaraWidgetMetal.allCases.endIndex
            < KaraWidgetMetal.allCases.firstIndex(of: $1.metal)
            ?? KaraWidgetMetal.allCases.endIndex
    }
}

private func karaSmallWidgetMarketLabel(
    _ metal: KaraWidgetFavoriteMetal
) -> String {
    let market = metal == .gold ? "Au 24k" : metal.symbol
    return "EUR • \(market)"
}

private func karaCoveragePercentage(_ portfolio: KaraWidgetPortfolio) -> Decimal? {
    guard portfolio.totalRecordCount > 0 else { return nil }
    return Decimal(portfolio.valuedRecordCount)
        / Decimal(portfolio.totalRecordCount)
        * 100
}

private func karaPortfolioRecordSummary(_ portfolio: KaraWidgetPortfolio) -> String {
    let label = String(localized: "widget.portfolio.records")
    return "\(portfolio.valuedRecordCount) \(label)"
}

private func karaPortfolioMetalSummary(_ quoteCount: Int) -> String {
    let prefix = String(localized: "widget.portfolio.coverage.distributed")
    let label = String(localized: "widget.portfolio.coverage.metals")
    return "\(prefix) \(quoteCount) \(label)"
}

private let karaHistoryAxisLabels = ["120 %", "100 %", "80 %", "60 %"]

private func karaHistoryMonthLabels(
    _ points: [KaraWidgetHistoryPoint]
) -> [String] {
    guard !points.isEmpty else { return [] }
    let labelCount = min(7, points.count)
    guard labelCount > 1 else {
        return [points[0].date.formatted(.dateTime.month(.abbreviated))]
    }
    let indexes = (0..<labelCount).map { index in
        index * (points.count - 1) / (labelCount - 1)
    }
    return indexes.map { index in
        points[index].date.formatted(.dateTime.month(.abbreviated))
    }
}

private func karaMarketAccessibilityValue(_ quote: KaraWidgetQuote) -> String {
    [
        karaQuoteAccessibilityValue(quote),
        karaQuoteAccessibilityValue(quote, usesOuncePrice: true),
        "\(String(localized: "widget.market.updated")) \(quote.sourceUpdatedAt.formatted(.dateTime.hour().minute()))",
    ].joined(separator: ". ")
}

private func karaQuoteAccessibilityValue(
    _ quote: KaraWidgetQuote,
    usesOuncePrice: Bool = false
) -> String {
    let price = usesOuncePrice ? quote.ouncePrice : quote.pricePerGram
    let unit = usesOuncePrice
        ? String(localized: "widget.market.per-ounce.accessibility")
        : String(localized: "widget.market.per-gram.accessibility")
    return "\(KaraWidgetFormatters.currency(price, maximumFractionDigits: 2)) \(unit)"
}

private func karaPortfolioAccessibilityValue(
    _ portfolio: KaraWidgetPortfolio
) -> String {
    var components = [KaraWidgetFormatters.currency(portfolio.totalValueEUR)]

    if let gain = portfolio.totalGainEUR {
        components.append(
            "\(String(localized: "widget.portfolio.gain.accessibility")): \(KaraWidgetFormatters.currency(gain, showsPositiveSign: true))"
        )
    }
    if let percentage = portfolio.gainPercentage {
        components.append(
            "\(String(localized: "widget.portfolio.performance.accessibility")): \(KaraWidgetFormatters.percentage(percentage))"
        )
    }

    components.append(
        "\(String(localized: "widget.portfolio.coverage.accessibility")): \(portfolio.valuedRecordCount)/\(portfolio.totalRecordCount)"
    )

    if portfolio.history.count >= 2 {
        components.append(karaHistoryAccessibilityValue(portfolio.history))
    }
    return components.joined(separator: ". ")
}

private func karaHistoryAccessibilityValue(
    _ points: [KaraWidgetHistoryPoint]
) -> String {
    guard let first = points.first,
          let latest = points.last,
          let minimum = points.min(by: { $0.valueEUR < $1.valueEUR }),
          let maximum = points.max(by: { $0.valueEUR < $1.valueEUR })
    else {
        return String(
            localized: "widget.portfolio.history.unavailable.accessibility"
        )
    }

    let trend: String
    if latest.valueEUR > first.valueEUR {
        trend = String(
            localized: "widget.portfolio.history.rising.accessibility"
        )
    } else if latest.valueEUR < first.valueEUR {
        trend = String(
            localized: "widget.portfolio.history.falling.accessibility"
        )
    } else {
        trend = String(
            localized: "widget.portfolio.history.stable.accessibility"
        )
    }

    return [
        trend,
        "\(String(localized: "widget.portfolio.history.current.accessibility")): \(KaraWidgetFormatters.currency(latest.valueEUR))",
        "\(String(localized: "widget.portfolio.history.minimum.accessibility")): \(KaraWidgetFormatters.currency(minimum.valueEUR))",
        "\(String(localized: "widget.portfolio.history.maximum.accessibility")): \(KaraWidgetFormatters.currency(maximum.valueEUR))",
    ].joined(separator: ". ")
}
