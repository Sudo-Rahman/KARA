import SwiftUI

struct AnalysisEvolutionView: View {
    @Environment(KaraTheme.self) private var theme

    let snapshot: PortfolioAnalyticsSnapshot

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: KaraSpacing.large) {
                Text(AnalysisCopy.resource("analysis.evolution.detail.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                AnalysisEvolutionCard(
                    snapshot: snapshot,
                    isRefreshing: false
                )

                AnalysisNotice(
                    systemImage: "info.circle",
                    title: "analysis.evolution.reading.title",
                    detail: "analysis.evolution.reading.detail",
                    tint: theme.cobaltBright
                )
            }
            .padding(.horizontal, KaraSpacing.medium)
            .padding(.top, KaraSpacing.small)
            .padding(.bottom, KaraSpacing.xxLarge)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(AnalysisCopy.resource("analysis.evolution.title"))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("analysis.evolution")
    }
}

struct AnalysisAllocationView: View {
    @Environment(KaraTheme.self) private var theme

    let snapshot: PortfolioAnalyticsSnapshot

    @State private var selectedKind: AnalysisBreakdownKind = .metals

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: KaraSpacing.large) {
                Text(AnalysisCopy.resource("analysis.allocation.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                Picker(
                    AnalysisCopy.resource("analysis.allocation.picker"),
                    selection: $selectedKind
                ) {
                    ForEach(AnalysisBreakdownKind.allCases) { kind in
                        Text(kind.label)
                            .tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .frame(minHeight: 44)
                .tint(theme.goldBright)
                .accessibilityIdentifier("analysis.allocation.picker")

                breakdownCard
            }
            .padding(.horizontal, KaraSpacing.medium)
            .padding(.top, KaraSpacing.small)
            .padding(.bottom, KaraSpacing.xxLarge)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(AnalysisCopy.resource("analysis.allocation.title"))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("analysis.allocation")
    }

    private var selectedBreakdown: PortfolioAnalyticsBreakdown {
        switch selectedKind {
        case .metals:
            snapshot.metals
        case .categories:
            snapshot.categories
        case .locations:
            snapshot.storageLocations
        }
    }

    private var breakdownCard: some View {
        KaraCard {
            VStack(alignment: .leading, spacing: 0) {
                if selectedBreakdown.items.isEmpty {
                    AnalysisCopy.text("analysis.allocation.unavailable")
                        .font(.subheadline)
                        .foregroundStyle(theme.muted)
                        .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
                } else {
                    ForEach(Array(selectedBreakdown.items.enumerated()), id: \.element.id) {
                        index,
                        item in
                        if index > 0 {
                            Divider()
                                .overlay(theme.muted.opacity(0.16))
                        }

                        breakdownRow(item, index: index)
                            .padding(.vertical, KaraSpacing.small)
                    }
                }

                if !selectedBreakdown.coverage.isComplete {
                    Divider()
                        .overlay(theme.muted.opacity(0.16))
                        .padding(.top, KaraSpacing.small)

                    Label(
                        AnalysisCopy.resource("analysis.allocation.partial"),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(theme.goldBright)
                    .padding(.top, KaraSpacing.medium)
                }
            }
        }
    }

    private func breakdownRow(
        _ item: PortfolioAnalyticsBreakdownItem,
        index: Int
    ) -> some View {
        HStack(spacing: KaraSpacing.medium) {
            Circle()
                .fill(color(for: index))
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                AnalysisBreakdownLabel(key: item.key, kind: selectedKind)
                    .font(.headline)
                    .foregroundStyle(theme.ink)

                Text(AnalysisCopy.formatted(
                    "analysis.allocation.records",
                    item.recordCount
                ))
                .font(.caption)
                .foregroundStyle(theme.muted)
            }

            Spacer(minLength: KaraSpacing.small)

            VStack(alignment: .trailing, spacing: KaraSpacing.xSmall) {
                SensitiveValue {
                    Text(VaultFormatters.currency(item.valueEUR))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(theme.ink)
                }

                if let share = item.sharePercentage {
                    SensitiveValue {
                        Text(VaultFormatters.percentage(share))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(theme.goldBright)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func color(for index: Int) -> Color {
        switch index % 4 {
        case 0:
            theme.goldBright
        case 1:
            theme.cobaltBright
        case 2:
            .cyan
        default:
            theme.muted
        }
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
