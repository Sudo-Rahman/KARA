import SwiftUI

struct AnalysisNotice: View {
    @Environment(KaraTheme.self) private var theme

    let systemImage: String
    let title: String.LocalizationValue
    let detail: String.LocalizationValue
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: KaraSpacing.medium) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.12), in: .circle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                AnalysisCopy.text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.ink)

                AnalysisCopy.text(detail)
                    .font(.caption)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(KaraSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08), in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(tint.opacity(0.20), lineWidth: 1)
        }
    }
}

struct AnalysisEvolutionCard: View {
    @Environment(KaraTheme.self) private var theme

    let snapshot: PortfolioAnalyticsSnapshot
    let isRefreshing: Bool

    var body: some View {
        KaraCard(padding: KaraSpacing.large) {
            VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                HStack(alignment: .firstTextBaseline) {
                    AnalysisCopy.text("analysis.evolution.current-value")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.muted)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.muted)
                        .accessibilityHidden(true)
                }

                currentValue

                if let change = snapshot.valueChange {
                    HStack(spacing: KaraSpacing.small) {
                        SensitiveValue {
                            Text(VaultFormatters.currency(
                                change.amountEUR,
                                showsPositiveSign: true
                            ))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(performanceColor(change.amountEUR))
                        }

                        if let percentage = change.percentage {
                            SensitiveValue {
                                Text(VaultFormatters.percentage(
                                    percentage,
                                    showsPositiveSign: true
                                ))
                                .font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundStyle(performanceColor(percentage))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(
                                    performanceColor(percentage).opacity(0.11),
                                    in: .capsule
                                )
                            }
                        }

                        Spacer(minLength: 0)
                    }
                }

                history

                if snapshot.historyCoverage.usesUnknownPurchaseDates {
                    Label(
                        AnalysisCopy.resource(
                            "analysis.evolution.unknown-purchase-dates"
                        ),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(theme.goldBright)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Label(
                    AnalysisCopy.resource("analysis.evolution.monthly-note"),
                    systemImage: "calendar"
                )
                .font(.caption)
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityIdentifier("analysis.evolution-card")
    }

    @ViewBuilder
    private var currentValue: some View {
        if let value = snapshot.currentValueEUR {
            SensitiveValue {
                Text(VaultFormatters.currency(value))
                    .font(theme.displayFont(size: 36, relativeTo: .largeTitle))
                    .monospacedDigit()
                    .foregroundStyle(theme.ink)
                    .karaMarketNumericTransition(value: value)
            }
        } else if isRefreshing {
            HStack(spacing: KaraSpacing.small) {
                ProgressView()
                AnalysisCopy.text("analysis.value.loading")
            }
            .font(.subheadline)
            .foregroundStyle(theme.muted)
        } else {
            AnalysisCopy.text("analysis.value.unavailable")
                .font(theme.displayFont(size: 26, relativeTo: .title2))
                .foregroundStyle(theme.muted)
        }
    }

    @ViewBuilder
    private var history: some View {
        if !snapshot.historyCoverage.canPresentChart {
            VStack(alignment: .leading, spacing: KaraSpacing.small) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.title2)
                    .foregroundStyle(theme.goldBright)
                    .accessibilityHidden(true)

                AnalysisCopy.text("analysis.evolution.incomplete-data")
                    .font(.subheadline)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        } else if snapshot.history.count >= 2,
           let first = snapshot.history.first,
           let last = snapshot.history.last,
           first.date < last.date {
            SensitiveValue {
                PortfolioHistoryChart(
                    points: snapshot.history,
                    domain: first.date ... last.date,
                    period: snapshot.period.historyPeriod,
                    accessibilityLabelKey: snapshot.period
                        .historyPeriod
                        .accessibilityLabelKey,
                    accessibilityIdentifier: "analysis.history.chart"
                )
            }
        } else {
            VStack(alignment: .leading, spacing: KaraSpacing.small) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.title2)
                    .foregroundStyle(theme.goldBright)
                    .accessibilityHidden(true)

                AnalysisCopy.text("analysis.evolution.not-enough-data")
                    .font(.subheadline)
                    .foregroundStyle(theme.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        }
    }

    private func performanceColor(_ value: Decimal) -> Color {
        if value > 0 { return .green }
        if value < 0 { return .red }
        return theme.muted
    }
}

struct AnalysisAllocationPreview: View {
    @Environment(KaraTheme.self) private var theme

    let breakdown: PortfolioAnalyticsBreakdown

    var body: some View {
        KaraCard(padding: KaraSpacing.large) {
            VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                HStack(alignment: .firstTextBaseline) {
                    AnalysisCopy.text("analysis.allocation.title")
                        .font(theme.displayFont(size: 21, relativeTo: .title3))
                        .foregroundStyle(theme.ink)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.muted)
                        .accessibilityHidden(true)
                }

                if let leading = breakdown.items.first,
                   let share = leading.sharePercentage {
                    HStack(spacing: KaraSpacing.medium) {
                        ZStack {
                            Circle()
                                .stroke(theme.surface, lineWidth: 10)
                                .accessibilityHidden(true)
                            Circle()
                                .trim(from: 0, to: min(1, max(0, share.vaultDouble / 100)))
                                .stroke(
                                    theme.goldBright,
                                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .accessibilityHidden(true)

                            SensitiveValue {
                                Text(VaultFormatters.percentage(share, maximumFractionDigits: 0))
                                    .font(.headline.monospacedDigit())
                                    .foregroundStyle(theme.ink)
                            }
                        }
                        .frame(width: 78, height: 78)

                        VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                            AnalysisCopy.text("analysis.allocation.leading")
                                .font(.caption)
                                .foregroundStyle(theme.muted)

                            AnalysisBreakdownLabel(
                                key: leading.key,
                                kind: .metals
                            )
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(theme.ink)

                            SensitiveValue {
                                Text(VaultFormatters.currency(leading.valueEUR))
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(theme.goldBright)
                            }
                        }
                    }
                } else {
                    AnalysisCopy.text("analysis.allocation.unavailable")
                        .font(.subheadline)
                        .foregroundStyle(theme.muted)
                        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
                }

                AnalysisCopy.text("analysis.allocation.detail")
                    .font(.caption)
                    .foregroundStyle(theme.muted)
            }
        }
        .accessibilityIdentifier("analysis.allocation-card")
    }
}

struct AnalysisSalesPreview: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let summary: PortfolioSalesAnalyticsSummary

    var body: some View {
        KaraCard(padding: KaraSpacing.large) {
            VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                HStack(alignment: .firstTextBaseline) {
                    AnalysisCopy.text("analysis.sales.title")
                        .font(theme.displayFont(size: 21, relativeTo: .title3))
                        .foregroundStyle(theme.ink)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.muted)
                        .accessibilityHidden(true)
                }

                if summary.saleCount == 0 {
                    HStack(spacing: KaraSpacing.medium) {
                        Image(systemName: "banknote")
                            .font(.title2)
                            .foregroundStyle(theme.goldBright)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                            AnalysisCopy.text("analysis.sales.empty.title")
                                .font(.headline)
                                .foregroundStyle(theme.ink)

                            AnalysisCopy.text("analysis.sales.empty.detail")
                                .font(.caption)
                                .foregroundStyle(theme.muted)
                        }
                    }
                } else {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                            salesMetrics
                        }
                    } else {
                        HStack(alignment: .top, spacing: KaraSpacing.large) {
                            salesMetrics
                        }
                    }

                    Text(salesCountDescription)
                    .font(.caption)
                    .foregroundStyle(theme.muted)
                }
            }
        }
        .accessibilityIdentifier("analysis.sales-card")
    }

    @ViewBuilder
    private var salesMetrics: some View {
        salesMetric(
            title: "analysis.sales.net-received",
            value: summary.netReceivedEUR,
            showsSign: false
        )
        salesMetric(
            title: "analysis.sales.realized-result",
            value: summary.realizedResultEUR,
            showsSign: true
        )
    }

    private func salesMetric(
        title: String.LocalizationValue,
        value: Decimal?,
        showsSign: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
            AnalysisCopy.text(title)
                .font(.caption)
                .foregroundStyle(theme.muted)

            if let value {
                SensitiveValue {
                    Text(VaultFormatters.currency(
                        value,
                        showsPositiveSign: showsSign
                    ))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(
                        showsSign
                            ? performanceColor(value)
                            : theme.ink
                    )
                }
            } else {
                Text("—")
                    .font(.headline)
                    .foregroundStyle(theme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func performanceColor(_ value: Decimal) -> Color {
        if value > 0 { return .green }
        if value < 0 { return .red }
        return theme.muted
    }

    private var salesCountDescription: String {
        AnalysisCopy.formatted(
            String.LocalizationValue(
                AnalysisSalesCountCopy.localizationKey(for: summary.saleCount)
            ),
            summary.saleCount
        )
    }
}

struct AnalysisInsightRow: View {
    @Environment(KaraTheme.self) private var theme

    let insight: PortfolioAnalyticsInsight

    var body: some View {
        HStack(alignment: .top, spacing: KaraSpacing.medium) {
            Image(systemName: symbolName)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.11), in: .circle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                if hasSensitiveTitle {
                    SensitiveValue {
                        insightTitle
                    }
                } else {
                    insightTitle
                }

                Text(verbatim: detail)
                    .font(.caption)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var insightTitle: some View {
        Text(verbatim: title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(theme.ink)
    }

    private var hasSensitiveTitle: Bool {
        switch insight {
        case .majorityMetal, .realizedSalesResult:
            true
        case .valuationDataIncomplete,
             .salesPerformanceDataIncomplete,
             .storageLocationDataIncomplete:
            false
        }
    }

    private var title: String {
        switch insight {
        case .valuationDataIncomplete:
            AnalysisCopy.string("analysis.insight.valuation.title")
        case .salesPerformanceDataIncomplete:
            AnalysisCopy.string("analysis.insight.sales.title")
        case .storageLocationDataIncomplete:
            AnalysisCopy.string("analysis.insight.storage.title")
        case let .majorityMetal(metal, share):
            AnalysisCopy.formatted(
                "analysis.insight.metal.title",
                localizedMetal(metal),
                VaultFormatters.percentage(share, maximumFractionDigits: 0)
            )
        case let .realizedSalesResult(amount):
            AnalysisCopy.formatted(
                "analysis.insight.result.title",
                VaultFormatters.currency(amount, showsPositiveSign: true)
            )
        }
    }

    private var detail: String {
        switch insight {
        case let .valuationDataIncomplete(count):
            AnalysisCopy.formatted("analysis.insight.valuation.detail", count)
        case let .salesPerformanceDataIncomplete(count):
            AnalysisCopy.formatted("analysis.insight.sales.detail", count)
        case let .storageLocationDataIncomplete(count):
            AnalysisCopy.formatted("analysis.insight.storage.detail", count)
        case .majorityMetal:
            AnalysisCopy.string("analysis.insight.metal.detail")
        case .realizedSalesResult:
            AnalysisCopy.string("analysis.insight.result.detail")
        }
    }

    private var symbolName: String {
        switch insight {
        case .valuationDataIncomplete, .salesPerformanceDataIncomplete:
            "exclamationmark.triangle.fill"
        case .storageLocationDataIncomplete:
            "mappin.and.ellipse"
        case .majorityMetal:
            "circle.hexagongrid.fill"
        case let .realizedSalesResult(amount):
            amount >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill"
        }
    }

    private var tint: Color {
        switch insight {
        case .valuationDataIncomplete,
             .salesPerformanceDataIncomplete,
             .storageLocationDataIncomplete:
            theme.goldBright
        case .majorityMetal:
            theme.cobaltBright
        case let .realizedSalesResult(amount):
            amount >= 0 ? .green : .red
        }
    }

    private func localizedMetal(_ metal: MarketMetal) -> String {
        let key = metal.preciousMetal.localizationKey
        let localized = String(localized: LocalizedStringResource(
            String.LocalizationValue(key)
        ))
        return localized == key ? metal.rawValue : localized
    }
}

enum AnalysisBreakdownKind: String, CaseIterable, Identifiable {
    case metals
    case categories
    case locations

    var id: Self { self }

    var label: LocalizedStringResource {
        switch self {
        case .metals:
            AnalysisCopy.resource("analysis.allocation.metals")
        case .categories:
            AnalysisCopy.resource("analysis.allocation.categories")
        case .locations:
            AnalysisCopy.resource("analysis.allocation.locations")
        }
    }
}

struct AnalysisBreakdownLabel: View {
    let key: String
    let kind: AnalysisBreakdownKind

    var body: some View {
        switch kind {
        case .metals:
            if let metal = MarketMetal(rawValue: key) {
                Text(metal.preciousMetal.localizedKey)
            } else {
                Text(verbatim: key)
            }
        case .categories:
            if let category = AssetCategory(rawValue: key) {
                Text(LocalizedStringKey(category.localizationKey))
            } else {
                Text(verbatim: key)
            }
        case .locations:
            Text(verbatim: key)
        }
    }
}
