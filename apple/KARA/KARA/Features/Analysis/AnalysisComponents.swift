import Charts
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let snapshot: PortfolioAnalyticsSnapshot

    var body: some View {
        KaraCard(padding: KaraSpacing.large) {
            VStack(alignment: .leading, spacing: KaraSpacing.large) {
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

                if breakdown.items.isEmpty {
                    AnalysisCopy.text("analysis.allocation.unavailable")
                        .font(.subheadline)
                        .foregroundStyle(theme.muted)
                        .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
                } else if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: KaraSpacing.large) {
                        previewChart
                            .frame(maxWidth: .infinity)
                        previewLegend
                    }
                } else {
                    HStack(spacing: KaraSpacing.large) {
                        previewChart
                        previewLegend
                    }
                }

                if !breakdown.items.isEmpty {
                    HStack(spacing: KaraSpacing.small) {
                        Label(
                            AnalysisCopy.formatted(
                                String.LocalizationValue(
                                    AnalysisAllocationCountCopy
                                        .groupLocalizationKey(
                                            for: breakdown.items.count
                                        )
                                ),
                                breakdown.items.count
                            ),
                            systemImage: "square.grid.2x2"
                        )
                        .font(.caption)
                        .foregroundStyle(theme.muted)

                        Spacer(minLength: KaraSpacing.small)

                        AnalysisCopy.text("analysis.allocation.explore")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.cobaltBright)
                    }
                }
            }
        }
        .accessibilityIdentifier("analysis.allocation-card")
    }

    private var breakdown: PortfolioAnalyticsBreakdown {
        snapshot.categories
    }

    private var previewChart: some View {
        ZStack {
            SensitiveValue {
                Chart {
                    ForEach(Array(breakdown.items.enumerated()), id: \.element.id) { index, item in
                        SectorMark(
                            angle: .value("Value", item.valueEUR.vaultDouble),
                            innerRadius: .ratio(0.68),
                            angularInset: 1.6
                        )
                        .cornerRadius(2)
                        .foregroundStyle(
                            AnalysisAllocationPalette.color(for: index, theme: theme)
                        )
                    }
                }
                .chartLegend(.hidden)
                .accessibilityHidden(true)
            }

            VStack(spacing: 2) {
                SensitiveValue {
                    Text(VaultFormatters.currency(
                        breakdown.coverage.totalKnownValueEUR
                    ))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.64)
                }

                AnalysisCopy.text("analysis.allocation.total-value")
                    .font(.caption2)
                    .foregroundStyle(theme.muted)
            }
            .padding(.horizontal, KaraSpacing.small)
        }
        .frame(width: 120, height: 120)
    }

    private var previewLegend: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.medium) {
            ForEach(Array(breakdown.items.prefix(3).enumerated()), id: \.element.id) {
                index,
                item in
                HStack(spacing: KaraSpacing.small) {
                    Circle()
                        .fill(AnalysisAllocationPalette.color(for: index, theme: theme))
                        .frame(width: 9, height: 9)
                        .accessibilityHidden(true)

                    AnalysisBreakdownLabel(key: item.key, kind: .categories)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)

                    Spacer(minLength: KaraSpacing.xSmall)

                    if let share = item.sharePercentage {
                        SensitiveValue {
                            Text(VaultFormatters.percentage(
                                share,
                                maximumFractionDigits: 0
                            ))
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(theme.goldBright)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

enum AnalysisBreakdownKind: String, CaseIterable, Identifiable {
    case categories
    case locations
    case metals

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
                AnalysisCopy.text(category.analysisAllocationLabel)
            } else {
                Text(verbatim: key)
            }
        case .locations:
            Text(verbatim: key)
        }
    }
}
