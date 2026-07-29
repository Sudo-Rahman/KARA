import SwiftUI

enum AnalysisRoute: Hashable {
    case performance
    case allocation
    case sales
}

struct AnalysisDashboardView: View {
    @Environment(AppRouter.self) private var router
    @Environment(KaraTheme.self) private var theme

    let valuation: PortfolioValuation
    let storageLocationsByAssetID: [UUID: String]
    let sales: [PortfolioAnalyticsSaleEntry]
    let valuationAsOf: Date
    let isRefreshing: Bool
    let isUsingCachedMarketData: Bool
    let refresh: @MainActor () async -> Void

    @State private var selectedPeriod: PortfolioAnalyticsPeriod = .oneYear

    private let engine = PortfolioAnalyticsEngine()

    var body: some View {
        let snapshot = engine.snapshot(
            valuation: valuation,
            storageLocationsByAssetID: storageLocationsByAssetID,
            sales: sales,
            period: selectedPeriod,
            asOf: valuationAsOf
        )

        ScrollView {
            LazyVStack(alignment: .leading, spacing: KaraSpacing.large) {
                introduction

                if isUsingCachedMarketData {
                    AnalysisNotice(
                        systemImage: "clock.arrow.circlepath",
                        title: "analysis.cached.title",
                        detail: "analysis.cached.detail",
                        tint: theme.goldBright
                    )
                }

                if valuation.coverage.totalRecordCount == 0 {
                    emptyVault(snapshot: snapshot)
                } else {
                    periodPicker

                    NavigationLink(value: AnalysisRoute.performance) {
                        AnalysisEvolutionCard(
                            snapshot: snapshot,
                            isRefreshing: isRefreshing
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(value: AnalysisRoute.allocation) {
                        AnalysisAllocationPreview(
                            snapshot: snapshot
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(value: AnalysisRoute.sales) {
                        AnalysisSalesPreview(summary: snapshot.sales)
                    }
                    .buttonStyle(.plain)
                }

                if valuation.coverage.totalRecordCount == 0,
                   snapshot.sales.saleCount > 0 {
                    NavigationLink(value: AnalysisRoute.sales) {
                        AnalysisSalesPreview(summary: snapshot.sales)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, KaraSpacing.medium)
            .padding(.top, KaraSpacing.small)
            .padding(.bottom, KaraSpacing.xxLarge)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await refresh()
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(AnalysisCopy.resource("analysis.title"))
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: AnalysisRoute.self) { route in
            destination(for: route, snapshot: snapshot)
        }
        .accessibilityIdentifier("analysis.dashboard")
    }

    private var introduction: some View {
        Text(AnalysisCopy.resource("analysis.subtitle"))
            .font(.subheadline)
            .foregroundStyle(theme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var periodPicker: some View {
        Picker(
            AnalysisCopy.resource("analysis.period.label"),
            selection: $selectedPeriod
        ) {
            ForEach(PortfolioAnalyticsPeriod.allCases, id: \.self) { period in
                Text(period.analysisLabel)
                    .tag(period)
            }
        }
        .pickerStyle(.segmented)
        .frame(minHeight: 44)
        .tint(theme.goldBright)
        .accessibilityIdentifier("analysis.period")
    }

    private func emptyVault(
        snapshot: PortfolioAnalyticsSnapshot
    ) -> some View {
        KaraCard(padding: KaraSpacing.large) {
            VStack(alignment: .leading, spacing: KaraSpacing.large) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(theme.goldBright)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: KaraSpacing.small) {
                    AnalysisCopy.text("analysis.empty.title")
                        .font(theme.displayFont(size: 23, relativeTo: .title2))
                        .foregroundStyle(theme.ink)

                    AnalysisCopy.text(
                        snapshot.sales.saleCount > 0
                            ? "analysis.empty.with-sales"
                            : "analysis.empty.detail"
                    )
                    .font(.subheadline)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    router.presentAssetCreation()
                } label: {
                    Label(
                        AnalysisCopy.resource("analysis.empty.action"),
                        systemImage: "plus"
                    )
                }
                .buttonStyle(.karaPrimaryAction)
            }
        }
    }

    @ViewBuilder
    private func destination(
        for route: AnalysisRoute,
        snapshot: PortfolioAnalyticsSnapshot
    ) -> some View {
        switch route {
        case .performance:
            AnalysisPerformanceView(
                snapshot: snapshot,
                valuationAsOf: valuationAsOf
            )
        case .allocation:
            AnalysisAllocationView(snapshot: snapshot)
        case .sales:
            SalesAnalysisView(summary: snapshot.sales)
        }
    }
}
