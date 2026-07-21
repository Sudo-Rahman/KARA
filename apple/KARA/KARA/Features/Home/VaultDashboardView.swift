import Charts
import SwiftUI

struct VaultDashboardView: View {
    @Environment(AppRouter.self) private var router
    @Environment(KaraTheme.self) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let assets: [Asset]
    let attachments: [AssetAttachment]
    let valuation: PortfolioValuation
    let goldQuote: SpotQuote?
    let isRefreshing: Bool
    let isUsingCachedMarketData: Bool
    let marketErrorDescription: String?
    let refresh: @MainActor () async -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: KaraSpacing.large) {
                introduction

                if assets.isEmpty {
                    emptyVaultCard
                } else {
                    portfolioHero
                    secondaryMetrics
                    if !valuation.metals.isEmpty {
                        metalsCard
                    }
                    historyCard
                }

                if !assets.isEmpty {
                    primaryActions
                }

                if !valuation.categories.isEmpty {
                    categoryCard
                }

                if !assets.isEmpty {
                    recentAssetsCard
                }

                liveGoldCard
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("KARA")
                    .font(theme.displayFont(size: 20, relativeTo: .headline))
                    .tracking(2.2)
                    .foregroundStyle(theme.goldBright)
                    .accessibilityAddTraits(.isHeader)
            }

            ToolbarItem(placement: .topBarTrailing) {
                PrivacyToolbarButton()
                .accessibilityIdentifier("vault.privacy-toggle")
            }
        }
        .accessibilityIdentifier("vault.dashboard")
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.small) {
            Text("vault.eyebrow")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundStyle(theme.goldBright)

            Text("vault.title")
                .font(theme.displayFont(size: 31, relativeTo: .largeTitle))
                .foregroundStyle(theme.ink)

            Text("vault.subtitle")
                .font(.subheadline)
                .foregroundStyle(theme.muted)
        }
        .accessibilityElement(children: .combine)
    }

    private var emptyVaultCard: some View {
        KaraCard(padding: KaraSpacing.large) {
            VStack(alignment: .leading, spacing: KaraSpacing.large) {
                ZStack {
                    Circle()
                        .fill(theme.gold.opacity(0.11))
                        .frame(width: 76, height: 76)

                    Image(systemName: "lock.open.trianglebadge.exclamationmark")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(theme.goldBright)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: KaraSpacing.small) {
                    Text("vault.empty.title")
                        .font(theme.displayFont(size: 23, relativeTo: .title2))
                        .foregroundStyle(theme.ink)

                    Text("vault.empty.body")
                        .font(.subheadline)
                        .foregroundStyle(theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    router.presentAssetCreation()
                } label: {
                    Label("vault.action.add", systemImage: "plus")
                }
                .buttonStyle(.karaPrimaryAction)
                .accessibilityIdentifier("home.add")
            }
        }
    }

    private var portfolioHero: some View {
        KaraCard(padding: KaraSpacing.large) {
            VStack(alignment: .leading, spacing: KaraSpacing.large) {
                HStack(alignment: .top, spacing: KaraSpacing.medium) {
                    VStack(alignment: .leading, spacing: KaraSpacing.small) {
                        Text("vault.metric.estimated-value")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(theme.muted)

                        if valuation.coverage.valuedRecordCount > 0 {
                            SensitiveValue {
                                Text(VaultFormatters.currency(valuation.totalEstimatedValueEUR))
                                    .font(theme.displayFont(size: 38, relativeTo: .largeTitle))
                                    .monospacedDigit()
                                    .foregroundStyle(theme.ink)
                                    .minimumScaleFactor(0.72)
                                    .lineLimit(1)
                                    .contentTransition(.numericText())
                            }
                        } else if isRefreshing {
                            HStack(spacing: KaraSpacing.small) {
                                ProgressView()
                                Text("vault.value.loading")
                            }
                            .font(.subheadline)
                            .foregroundStyle(theme.muted)
                        } else {
                            Text("vault.value.unavailable")
                                .font(theme.displayFont(size: 38, relativeTo: .largeTitle))
                                .foregroundStyle(theme.muted)
                        }
                    }

                    Spacer(minLength: KaraSpacing.small)

                    Image(systemName: "sparkles")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(theme.goldBright)
                        .frame(width: 44, height: 44)
                        .background(theme.gold.opacity(0.11), in: .circle)
                        .accessibilityHidden(true)
                }

                Group {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: KaraSpacing.small) {
                            coverageStatus
                            coverageRecordCount
                        }
                    } else {
                        HStack(spacing: KaraSpacing.small) {
                            coverageStatus
                            Spacer(minLength: KaraSpacing.small)
                            coverageRecordCount
                        }
                    }
                }

                if valuation.coverage.valuedRecordCount < valuation.coverage.totalRecordCount {
                    Text("vault.coverage.explanation")
                        .font(.caption)
                        .foregroundStyle(theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityIdentifier("vault.estimated-value")
    }

    @ViewBuilder
    private var coverageStatus: some View {
        if valuation.coverage.valuedRecordCount == valuation.coverage.totalRecordCount {
            VaultStatusPill(
                text: "vault.coverage.complete",
                systemImage: "checkmark.seal.fill",
                tint: .green
            )
        } else {
            VaultStatusPill(
                text: "vault.coverage.partial",
                systemImage: "exclamationmark.triangle.fill",
                tint: theme.goldBright
            )
        }
    }

    private var coverageRecordCount: some View {
        SensitiveValue {
            Text("vault.coverage.records \(valuation.coverage.valuedRecordCount) \(valuation.coverage.totalRecordCount)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(theme.muted)
        }
    }

    private var secondaryMetrics: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: KaraSpacing.small) {
                    gainMetricCard
                    inventoryMetricCard
                }
            } else {
                HStack(alignment: .top, spacing: KaraSpacing.small) {
                    gainMetricCard
                    inventoryMetricCard
                }
            }
        }
    }

    private var gainMetricCard: some View {
        KaraCard(padding: KaraSpacing.medium) {
            KaraMetric(title: "vault.metric.unrealized-gain", systemImage: "chart.line.uptrend.xyaxis") {
                if let gain = valuation.totalGainEUR {
                    SensitiveValue {
                        Text(VaultFormatters.currency(gain, showsPositiveSign: true))
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(performanceColor(gain))
                            .minimumScaleFactor(0.68)
                            .lineLimit(1)
                    }
                } else {
                    Text("vault.value.unavailable")
                        .font(.title3.weight(.semibold))
                }
            } detail: {
                VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                    if let percentage = valuation.gainPercentage {
                        SensitiveValue {
                            Text(VaultFormatters.percentage(percentage, showsPositiveSign: true))
                                .monospacedDigit()
                                .foregroundStyle(performanceColor(percentage))
                        }
                    } else {
                        Text("vault.performance.missing-cost")
                    }

                    if valuation.coverage.performanceRecordCount < valuation.coverage.valuedRecordCount {
                        SensitiveValue {
                            Text("vault.performance.partial \(valuation.coverage.performanceRecordCount) \(valuation.coverage.valuedRecordCount)")
                                .font(.caption2)
                                .foregroundStyle(theme.goldBright)
                        }
                    }
                }
            }
        }
    }

    private var inventoryMetricCard: some View {
        Button {
            router.showInventory()
        } label: {
            KaraCard(padding: KaraSpacing.medium) {
                KaraMetric(title: "vault.metric.inventory", systemImage: "shippingbox.fill") {
                    SensitiveValue {
                        Text("vault.metric.objects \(valuation.coverage.totalObjectCount)")
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                            .minimumScaleFactor(0.68)
                            .lineLimit(1)
                    }
                } detail: {
                    SensitiveValue {
                        Text("vault.metric.records \(valuation.coverage.totalRecordCount)")
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("vault.metric.inventory.hint"))
        .accessibilityIdentifier("vault.inventory-card")
    }

    private var metalsCard: some View {
        KaraCard {
            VStack(alignment: .leading, spacing: 0) {
                VaultSectionHeader("vault.metals.title", eyebrow: "vault.metals.eyebrow")
                    .padding(.bottom, KaraSpacing.small)

                ForEach(Array(valuation.metals.enumerated()), id: \.element.id) { index, metal in
                    if index > 0 {
                        Divider()
                            .overlay(theme.muted.opacity(0.16))
                    }

                    HStack(spacing: KaraSpacing.medium) {
                        Image(systemName: metal.metal.preciousMetal.symbolName)
                            .font(.headline)
                            .foregroundStyle(metalTint(metal.metal))
                            .frame(width: 38, height: 38)
                            .background(metalTint(metal.metal).opacity(0.10), in: .circle)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                            Text(metal.metal.preciousMetal.localizedKey)
                                .font(.headline)
                                .foregroundStyle(theme.ink)

                            SensitiveValue {
                                Text(VaultFormatters.weight(metal.fineWeightGrams))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(theme.muted)
                            }
                        }

                        Spacer(minLength: KaraSpacing.small)

                        VStack(alignment: .trailing, spacing: KaraSpacing.xSmall) {
                            if let value = metal.estimatedValueEUR {
                                SensitiveValue {
                                    Text(VaultFormatters.currency(value))
                                        .font(.headline.monospacedDigit())
                                        .foregroundStyle(theme.ink)
                                }
                            } else {
                                Text("vault.value.unavailable")
                                    .font(.headline)
                                    .foregroundStyle(theme.muted)
                            }

                            if let share = metal.sharePercentage {
                                SensitiveValue {
                                    Text(VaultFormatters.percentage(share))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(theme.goldBright)
                                }
                            }
                        }
                    }
                    .padding(.vertical, KaraSpacing.small)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private var historyCard: some View {
        KaraCard {
            VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                VaultSectionHeader("vault.history.title", eyebrow: "vault.history.eyebrow") {
                    if let percentage = valuation.gainPercentage {
                        SensitiveValue {
                            Text(VaultFormatters.percentage(percentage, showsPositiveSign: true))
                                .font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundStyle(performanceColor(percentage))
                        }
                    }
                }

                if valuation.history.count >= 2 {
                    SensitiveValue {
                        portfolioChart
                    }
                } else {
                    VStack(alignment: .leading, spacing: KaraSpacing.small) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.title2)
                            .foregroundStyle(theme.goldBright)

                        Text("vault.history.not-enough-data")
                            .font(.subheadline)
                            .foregroundStyle(theme.muted)
                    }
                    .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
                }

                if valuation.historyUsesUnknownPurchaseDates {
                    Label("vault.history.unknown-dates", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(theme.muted)
                }
            }
        }
    }

    private var portfolioChart: some View {
        Chart(valuation.history) { point in
            AreaMark(
                x: .value("Date", point.date),
                y: .value("Value", point.valueEUR.vaultDouble)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [theme.cobaltBright.opacity(0.30), theme.cobalt.opacity(0.01)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            LineMark(
                x: .value("Date", point.date),
                y: .value("Value", point.valueEUR.vaultDouble)
            )
            .foregroundStyle(theme.goldBright)
            .lineStyle(.init(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            .interpolationMethod(.catmullRom)

            if point.isCurrent {
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.valueEUR.vaultDouble)
                )
                .foregroundStyle(theme.goldBright)
                .symbolSize(58)
            }
        }
        .chartLegend(.hidden)
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.month(.abbreviated))
                            .font(.caption2)
                            .foregroundStyle(theme.muted)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                    .foregroundStyle(theme.muted.opacity(0.16))
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(VaultFormatters.currency(Decimal(amount)))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(theme.muted)
                    }
                }
            }
        }
        .frame(height: 190)
        .accessibilityLabel(Text("vault.history.accessibility-label"))
    }

    private var primaryActions: some View {
        VStack(spacing: KaraSpacing.small) {
            Button {
                router.presentAssetCreation()
            } label: {
                Label("vault.action.add", systemImage: "plus")
            }
            .buttonStyle(.karaPrimaryAction)
            .accessibilityIdentifier("home.add")

            Button {
                router.presentSaleSimulation()
            } label: {
                Label("vault.action.simulate", systemImage: "equal.circle")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.glass)
            .disabled(valuation.coverage.valuedRecordCount == 0)
            .accessibilityIdentifier("vault.simulate")
        }
    }

    private var categoryCard: some View {
        KaraCard {
            VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                VaultSectionHeader("vault.categories.title", eyebrow: "vault.categories.eyebrow")

                ForEach(valuation.categories) { category in
                    let assetCategory = AssetCategory(rawValue: category.categoryID) ?? .custom

                    HStack(spacing: KaraSpacing.medium) {
                        AssetArtworkView(category: assetCategory, size: 44)

                        VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                            Text(LocalizedStringKey(assetCategory.localizationKey))
                                .font(.headline)
                                .foregroundStyle(theme.ink)

                            SensitiveValue {
                                Text("vault.metric.objects \(category.objectCount)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(theme.muted)
                            }
                        }

                        Spacer(minLength: KaraSpacing.small)

                        VStack(alignment: .trailing, spacing: KaraSpacing.xSmall) {
                            if let value = category.estimatedValueEUR {
                                SensitiveValue {
                                    Text(VaultFormatters.currency(value))
                                        .font(.headline.monospacedDigit())
                                        .foregroundStyle(theme.ink)
                                }
                            }

                            if let share = category.sharePercentage {
                                SensitiveValue {
                                    Text(VaultFormatters.percentage(share))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(theme.goldBright)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var recentAssetsCard: some View {
        let valuesByAssetID = assetValuations
        let photosByAssetID = newestObjectPhotoDataByAssetID(attachments: attachments)

        return KaraCard {
            VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                VaultSectionHeader("vault.recent.title", eyebrow: "vault.recent.eyebrow") {
                    Button("vault.action.view-all") {
                        router.showInventory()
                    }
                    .font(.caption.weight(.semibold))
                }

                ForEach(Array(recentAssets.enumerated()), id: \.element.id) { index, asset in
                    if index > 0 {
                        Divider()
                            .overlay(theme.muted.opacity(0.16))
                    }

                    Button {
                        router.showAsset(asset.id)
                    } label: {
                        recentAssetRow(
                            asset,
                            valuation: valuesByAssetID[asset.id],
                            photoData: photosByAssetID[asset.id]
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("home.asset.\(asset.id.uuidString)")
                }
            }
        }
        .accessibilityIdentifier("home.assets")
    }

    private func recentAssetRow(
        _ asset: Asset,
        valuation itemValuation: AssetValuation?,
        photoData: Data?
    ) -> some View {
        HStack(spacing: KaraSpacing.medium) {
            AssetArtworkView(
                category: asset.category,
                photoData: photoData,
                size: 52
            )

            VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                Text(asset.name)
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(LocalizedStringKey(asset.category.localizationKey))
                    if asset.quantity > 1 {
                        SensitiveValue {
                            Text("×\(asset.quantity)")
                        }
                    }
                }
                .font(.caption)
                .foregroundStyle(theme.muted)
            }

            Spacer(minLength: KaraSpacing.small)

            VStack(alignment: .trailing, spacing: KaraSpacing.xSmall) {
                if let value = itemValuation?.estimatedValueEUR {
                    SensitiveValue {
                        Text(VaultFormatters.currency(value))
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(theme.ink)
                    }
                } else {
                    Text("vault.value.unavailable")
                        .font(.subheadline)
                        .foregroundStyle(theme.muted)
                }

                if let gain = itemValuation?.gainPercentage {
                    SensitiveValue {
                        Text(VaultFormatters.percentage(gain, showsPositiveSign: true))
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(performanceColor(gain))
                    }
                }
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var liveGoldCard: some View {
        KaraCard(padding: KaraSpacing.large) {
            VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                        Text("vault.gold-live.eyebrow")
                            .font(.caption2.weight(.semibold))
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(theme.goldBright)

                        Text("vault.gold-live.title")
                            .font(theme.displayFont(size: 21, relativeTo: .title3))
                            .foregroundStyle(theme.ink)
                    }

                    Spacer()

                    if isRefreshing {
                        ProgressView()
                            .tint(theme.goldBright)
                            .accessibilityLabel(Text("vault.market.refreshing"))
                    } else if isUsingCachedMarketData && goldQuote != nil {
                        VaultStatusPill(
                            text: "vault.market.cached",
                            systemImage: "clock.arrow.circlepath",
                            tint: theme.goldBright
                        )
                    } else if goldQuote != nil {
                        VaultStatusPill(
                            text: "vault.market.available",
                            systemImage: "dot.radiowaves.left.and.right",
                            tint: .green
                        )
                    }
                }

                if let goldQuote {
                    HStack(alignment: .firstTextBaseline, spacing: KaraSpacing.small) {
                        Text(VaultFormatters.currency(goldQuote.pricePerGram, maximumFractionDigits: 2))
                            .font(theme.displayFont(size: 31, relativeTo: .title))
                            .monospacedDigit()
                            .foregroundStyle(theme.ink)

                        Text("vault.gold-live.per-gram")
                            .font(.subheadline)
                            .foregroundStyle(theme.muted)
                    }
                    .contentTransition(.numericText())

                    HStack(alignment: .firstTextBaseline) {
                        Text("vault.gold-live.per-ounce \(VaultFormatters.currency(goldQuote.price, maximumFractionDigits: 2))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(theme.muted)

                        Spacer(minLength: KaraSpacing.small)

                        Text(goldQuote.sourceUpdatedAt, format: .dateTime.day().month(.abbreviated).hour().minute())
                            .font(.caption2)
                            .foregroundStyle(theme.muted)
                    }

                    Text("vault.gold-live.no-daily-change")
                        .font(.caption2)
                        .foregroundStyle(theme.muted)
                } else {
                    Label("vault.market.unavailable", systemImage: "wifi.exclamationmark")
                        .font(.subheadline)
                        .foregroundStyle(theme.muted)

                    if marketErrorDescription != nil {
                        Button("vault.market.retry") {
                            Task { await refresh() }
                        }
                        .buttonStyle(.glass)
                    }
                }
            }
        }
        .accessibilityIdentifier("vault.gold-live")
    }

    private var recentAssets: [Asset] {
        Array(assets.sorted { $0.createdAt > $1.createdAt }.prefix(3))
    }

    private var assetValuations: [UUID: AssetValuation] {
        Dictionary(uniqueKeysWithValues: valuation.assetValuations.map { ($0.assetID, $0) })
    }

    private func performanceColor(_ value: Decimal) -> Color {
        if value > 0 { return .green }
        if value < 0 { return .red }
        return theme.muted
    }

    private func metalTint(_ metal: MarketMetal) -> Color {
        switch metal {
        case .gold:
            theme.goldBright
        case .silver:
            Color(white: 0.84)
        case .platinum:
            theme.cobaltBright
        case .palladium:
            Color.cyan
        }
    }
}
