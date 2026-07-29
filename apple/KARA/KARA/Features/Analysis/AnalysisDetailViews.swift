import Charts
import SwiftUI

struct AnalysisPerformanceView: View {
    @Environment(KaraTheme.self) private var theme

    let snapshot: PortfolioAnalyticsSnapshot
    let valuationAsOf: Date

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: KaraSpacing.large) {
                Text(AnalysisCopy.resource("analysis.performance.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                if snapshot.performance.isAvailable {
                    overviewCard
                    rankingCard
                    categoryComparisonCard
                } else {
                    unavailableCard
                }

                AnalysisNotice(
                    systemImage: "info.circle",
                    title: "analysis.performance.reading.title",
                    detail: "analysis.performance.reading.detail",
                    tint: theme.cobaltBright
                )
            }
            .padding(.horizontal, KaraSpacing.medium)
            .padding(.top, KaraSpacing.small)
            .padding(.bottom, KaraSpacing.xxLarge)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(AnalysisCopy.resource("analysis.performance.title"))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("analysis.performance")
    }

    private var overviewCard: some View {
        let performance = snapshot.performance

        return KaraCard(padding: KaraSpacing.large) {
            VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                    AnalysisCopy.text("analysis.performance.unrealized-gain")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.muted)

                    if let gain = performance.unrealizedGainEUR {
                        HStack(alignment: .firstTextBaseline, spacing: KaraSpacing.small) {
                            SensitiveValue {
                                Text(VaultFormatters.currency(
                                    gain,
                                    showsPositiveSign: true
                                ))
                                .font(theme.displayFont(size: 36, relativeTo: .largeTitle))
                                .monospacedDigit()
                                .foregroundStyle(performanceColor(gain))
                            }

                            if let rate = performance.returnPercentage {
                                performanceBadge(rate)
                            }
                        }
                    }
                }

                Divider()
                    .overlay(theme.muted.opacity(0.16))

                HStack(alignment: .top, spacing: KaraSpacing.large) {
                    overviewMetric(
                        title: "analysis.performance.current-value",
                        value: performance.currentValueEUR
                    )
                    overviewMetric(
                        title: "analysis.performance.purchase-cost",
                        value: performance.purchaseCostEUR
                    )
                }

                periodChange

                Label(
                    AnalysisCopy.formatted(
                        "analysis.performance.coverage",
                        performance.coverage.includedRecordCount,
                        performance.coverage.totalRecordCount
                    ),
                    systemImage: performance.coverage.isComplete
                        ? "checkmark.circle.fill"
                        : "exclamationmark.triangle.fill"
                )
                .font(.caption)
                .foregroundStyle(
                    performance.coverage.isComplete
                        ? theme.cobaltBright
                        : theme.goldBright
                )
            }
        }
        .accessibilityIdentifier("analysis.performance.overview")
    }

    private var periodChange: some View {
        HStack(spacing: KaraSpacing.medium) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.headline)
                .foregroundStyle(theme.goldBright)
                .frame(width: 36, height: 36)
                .background(theme.gold.opacity(0.12), in: .circle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                Text(AnalysisCopy.formatted(
                    "analysis.performance.period-change",
                    String(localized: snapshot.period.analysisLabel)
                ))
                .font(.caption)
                .foregroundStyle(theme.muted)

                if let change = snapshot.valueChange {
                    HStack(alignment: .firstTextBaseline, spacing: KaraSpacing.small) {
                        SensitiveValue {
                            Text(VaultFormatters.currency(
                                change.amountEUR,
                                showsPositiveSign: true
                            ))
                            .font(.headline.monospacedDigit())
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
                            }
                        }
                    }
                } else {
                    AnalysisCopy.text("analysis.performance.period-unavailable")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.muted)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(KaraSpacing.medium)
        .background(theme.cobalt.opacity(0.08), in: .rect(cornerRadius: 16))
    }

    private var rankingCard: some View {
        let rankedAssets = Array(snapshot.performance.rankedAssets.prefix(5))
        let maximumMagnitude = rankedAssets
            .map { abs($0.unrealizedGainEUR.vaultDouble) }
            .max() ?? 1

        return KaraCard(padding: KaraSpacing.large) {
            VStack(alignment: .leading, spacing: KaraSpacing.large) {
                sectionHeader(
                    title: "analysis.performance.ranking.title",
                    detail: "analysis.performance.ranking.detail"
                )

                ForEach(rankedAssets) { asset in
                    VStack(alignment: .leading, spacing: KaraSpacing.small) {
                        HStack(alignment: .firstTextBaseline, spacing: KaraSpacing.small) {
                            Text(asset.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(theme.ink)
                                .lineLimit(1)

                            Spacer(minLength: KaraSpacing.small)

                            SensitiveValue {
                                Text(VaultFormatters.currency(
                                    asset.unrealizedGainEUR,
                                    showsPositiveSign: true
                                ))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(performanceColor(asset.unrealizedGainEUR))
                            }
                        }

                        GeometryReader { geometry in
                            let ratio = maximumMagnitude == 0
                                ? 0
                                : abs(asset.unrealizedGainEUR.vaultDouble) / maximumMagnitude

                            Capsule()
                                .fill(theme.muted.opacity(0.12))
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(barColor(asset.unrealizedGainEUR))
                                        .frame(width: geometry.size.width * ratio)
                                }
                        }
                        .frame(height: 8)

                        if let rate = asset.returnPercentage {
                            SensitiveValue {
                                Text(VaultFormatters.percentage(
                                    rate,
                                    showsPositiveSign: true
                                ))
                                .font(.caption2.weight(.medium).monospacedDigit())
                                .foregroundStyle(performanceColor(rate))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .accessibilityIdentifier("analysis.performance.ranking")
    }

    private var categoryComparisonCard: some View {
        let categories = Array(snapshot.performance.categories.prefix(3))

        return KaraCard(padding: KaraSpacing.large) {
            VStack(alignment: .leading, spacing: KaraSpacing.large) {
                sectionHeader(
                    title: "analysis.performance.categories.title",
                    detail: "analysis.performance.categories.detail"
                )

                SensitiveValue {
                    Chart(categories) { category in
                        BarMark(
                            x: .value("Category", category.categoryID),
                            y: .value(
                                AnalysisCopy.string("analysis.performance.current-value"),
                                category.currentValueEUR.vaultDouble
                            )
                        )
                        .position(by: .value(
                            "Series",
                            AnalysisCopy.string("analysis.performance.current-value")
                        ))
                        .foregroundStyle(theme.goldBright)
                        .clipShape(.rect(cornerRadius: 4))

                        BarMark(
                            x: .value("Category", category.categoryID),
                            y: .value(
                                AnalysisCopy.string("analysis.performance.purchase-cost"),
                                category.purchaseCostEUR.vaultDouble
                            )
                        )
                        .position(by: .value(
                            "Series",
                            AnalysisCopy.string("analysis.performance.purchase-cost")
                        ))
                        .foregroundStyle(theme.cobaltBright.opacity(0.55))
                        .clipShape(.rect(cornerRadius: 4))
                    }
                    .chartXAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let categoryID = value.as(String.self) {
                                    AnalysisBreakdownLabel(
                                        key: categoryID,
                                        kind: .categories
                                    )
                                    .font(.caption2)
                                    .foregroundStyle(theme.muted)
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                                .foregroundStyle(theme.muted.opacity(0.12))
                            AxisValueLabel {
                                if let amount = value.as(Double.self) {
                                    Text(amount, format: .currency(code: "EUR").notation(.compactName))
                                        .font(.caption2)
                                        .foregroundStyle(theme.muted)
                                }
                            }
                        }
                    }
                    .chartLegend(.hidden)
                    .frame(height: 220)
                }

                HStack(spacing: KaraSpacing.large) {
                    legend(
                        title: "analysis.performance.current-value",
                        color: theme.goldBright
                    )
                    legend(
                        title: "analysis.performance.purchase-cost",
                        color: theme.cobaltBright.opacity(0.55)
                    )
                }

                Text(AnalysisCopy.formatted(
                    "analysis.performance.as-of",
                    valuationAsOf.formatted(date: .abbreviated, time: .omitted)
                ))
                .font(.caption2)
                .foregroundStyle(theme.muted)
            }
        }
        .accessibilityIdentifier("analysis.performance.categories")
    }

    private var unavailableCard: some View {
        KaraCard(padding: KaraSpacing.large) {
            VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(theme.goldBright)
                    .accessibilityHidden(true)

                AnalysisCopy.text("analysis.performance.unavailable.title")
                    .font(theme.displayFont(size: 23, relativeTo: .title2))
                    .foregroundStyle(theme.ink)

                AnalysisCopy.text("analysis.performance.unavailable.detail")
                    .font(.subheadline)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func overviewMetric(
        title: String.LocalizationValue,
        value: Decimal?
    ) -> some View {
        VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
            AnalysisCopy.text(title)
                .font(.caption)
                .foregroundStyle(theme.muted)

            if let value {
                SensitiveValue {
                    Text(VaultFormatters.currency(value))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(theme.ink)
                }
            } else {
                Text("—")
                    .font(.headline)
                    .foregroundStyle(theme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionHeader(
        title: String.LocalizationValue,
        detail: String.LocalizationValue
    ) -> some View {
        VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
            AnalysisCopy.text(title)
                .font(theme.displayFont(size: 21, relativeTo: .title3))
                .foregroundStyle(theme.ink)

            AnalysisCopy.text(detail)
                .font(.caption)
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func performanceBadge(_ value: Decimal) -> some View {
        SensitiveValue {
            Text(VaultFormatters.percentage(
                value,
                showsPositiveSign: true
            ))
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(performanceColor(value))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(performanceColor(value).opacity(0.11), in: .capsule)
        }
    }

    private func legend(
        title: String.LocalizationValue,
        color: Color
    ) -> some View {
        HStack(spacing: KaraSpacing.small) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 12, height: 12)
                .accessibilityHidden(true)

            AnalysisCopy.text(title)
                .font(.caption)
                .foregroundStyle(theme.muted)
        }
    }

    private func barColor(_ value: Decimal) -> Color {
        value < 0 ? .red : theme.goldBright
    }

    private func performanceColor(_ value: Decimal) -> Color {
        if value > 0 { return .green }
        if value < 0 { return .red }
        return theme.muted
    }
}

struct SalesAnalysisView: View {
    @Environment(KaraTheme.self) private var theme

    let summary: PortfolioSalesAnalyticsSummary

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: KaraSpacing.large) {
                Text(AnalysisCopy.resource("analysis.sales.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                if summary.saleCount == 0 {
                    emptyState
                } else {
                    receivedCard
                    resultCard

                    if summary.coverage.isSpotComparisonComplete,
                       let comparison = summary.grossProceedsComparedToSpotEUR {
                        spotComparisonCard(comparison)
                    }

                    explanationCard
                }
            }
            .padding(.horizontal, KaraSpacing.medium)
            .padding(.top, KaraSpacing.small)
            .padding(.bottom, KaraSpacing.xxLarge)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(AnalysisCopy.resource("analysis.sales.title"))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("analysis.sales")
    }

    private var emptyState: some View {
        KaraCard(padding: KaraSpacing.large) {
            VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(theme.goldBright)
                    .accessibilityHidden(true)

                AnalysisCopy.text("analysis.sales.empty.title")
                    .font(theme.displayFont(size: 23, relativeTo: .title2))
                    .foregroundStyle(theme.ink)

                AnalysisCopy.text("analysis.sales.empty.detail")
                    .font(.subheadline)
                    .foregroundStyle(theme.muted)
            }
        }
    }

    private var receivedCard: some View {
        KaraCard(padding: KaraSpacing.large) {
            VStack(alignment: .leading, spacing: KaraSpacing.small) {
                AnalysisCopy.text("analysis.sales.net-received")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.muted)

                if let net = summary.netReceivedEUR {
                    SensitiveValue {
                        Text(VaultFormatters.currency(net))
                            .font(theme.displayFont(size: 36, relativeTo: .largeTitle))
                            .monospacedDigit()
                            .foregroundStyle(theme.ink)
                    }
                } else {
                    Text("—")
                        .font(theme.displayFont(size: 36, relativeTo: .largeTitle))
                        .foregroundStyle(theme.muted)
                }

                Text(salesCountDescription)
                .font(.caption)
                .foregroundStyle(theme.muted)

                if !summary.coverage.isNetReceivedComplete {
                    partialCoverage
                }
            }
        }
    }

    private var resultCard: some View {
        KaraCard(padding: KaraSpacing.large) {
            VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                AnalysisCopy.text("analysis.sales.realized-result")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.muted)

                if let result = summary.realizedResultEUR {
                    HStack(alignment: .firstTextBaseline, spacing: KaraSpacing.small) {
                        SensitiveValue {
                            Text(VaultFormatters.currency(
                                result,
                                showsPositiveSign: true
                            ))
                            .font(theme.displayFont(size: 32, relativeTo: .title))
                            .monospacedDigit()
                            .foregroundStyle(performanceColor(result))
                        }

                        if let rate = summary.realizedRatePercentage {
                            SensitiveValue {
                                Text(VaultFormatters.percentage(
                                    rate,
                                    showsPositiveSign: true
                                ))
                                .font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundStyle(performanceColor(rate))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(
                                    performanceColor(rate).opacity(0.11),
                                    in: .capsule
                                )
                            }
                        }
                    }
                } else {
                    AnalysisCopy.text("analysis.sales.result-unavailable")
                        .font(.headline)
                        .foregroundStyle(theme.muted)
                }

                if !summary.coverage.isRealizedResultComplete {
                    partialCoverage
                }
            }
        }
    }

    private func spotComparisonCard(_ comparison: Decimal) -> some View {
        KaraCard {
            HStack(spacing: KaraSpacing.medium) {
                Image(systemName: "scalemass.fill")
                    .font(.title3)
                    .foregroundStyle(theme.cobaltBright)
                    .frame(width: 42, height: 42)
                    .background(theme.cobalt.opacity(0.12), in: .circle)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                    AnalysisCopy.text("analysis.sales.spot-comparison")
                        .font(.subheadline)
                        .foregroundStyle(theme.muted)

                    SensitiveValue {
                        Text(VaultFormatters.currency(
                            comparison,
                            showsPositiveSign: true
                        ))
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .foregroundStyle(performanceColor(comparison))
                    }
                }
            }
        }
    }

    private var explanationCard: some View {
        AnalysisNotice(
            systemImage: "equal.circle",
            title: "analysis.sales.reading.title",
            detail: "analysis.sales.reading.detail",
            tint: theme.cobaltBright
        )
    }

    private var partialCoverage: some View {
        Label(
            AnalysisCopy.resource("analysis.sales.partial"),
            systemImage: "exclamationmark.triangle.fill"
        )
        .font(.caption)
        .foregroundStyle(theme.goldBright)
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
