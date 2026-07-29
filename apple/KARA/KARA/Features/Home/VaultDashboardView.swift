import SwiftUI

struct VaultDashboardView: View {
    @Environment(AppRouter.self) private var router
    @Environment(KaraTheme.self) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedMetal: MarketMetal = .gold

    let assets: [Asset]
    let attachments: [AssetAttachment]
    let valuation: PortfolioValuation
    let metalQuotes: [MarketMetal: SpotQuote]
    let isRefreshing: Bool
    let isUsingCachedMarketData: Bool
    let refresh: @MainActor () async -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: KaraSpacing.large) {
                if assets.isEmpty {
                    emptyVaultCard
                } else {
                    portfolioHero
                    secondaryMetrics
                }

                if !assets.isEmpty {
                    primaryActions
                }

                if !assets.isEmpty {
                    recentAssetsCard
                }

                metalPricesCard
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
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Kara")
                    .font(theme.displayFont(size: 20, relativeTo: .headline))
                    .foregroundStyle(theme.goldBright)
                    .accessibilityAddTraits(.isHeader)
            }
        }
        .accessibilityIdentifier("vault.dashboard")
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
                                    .karaMarketNumericTransition(
                                        value: valuation.totalEstimatedValueEUR
                                    )
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

                    PrivacyToggleButton()
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
        .accessibilityElement(children: .contain)
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
        KaraCard(
            padding: KaraSpacing.medium,
            height: compactMetricCardHeight
        ) {
            KaraMetric(title: "vault.metric.unrealized-gain", systemImage: "chart.line.uptrend.xyaxis") {
                if let gain = valuation.totalGainEUR {
                    SensitiveValue {
                        Text(VaultFormatters.currency(gain, showsPositiveSign: true))
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(performanceColor(gain))
                            .minimumScaleFactor(0.68)
                            .lineLimit(1)
                            .karaMarketNumericTransition(value: gain)
                    }
                } else {
                    Text("vault.value.unavailable")
                        .font(.title3.weight(.semibold))
                }
            } detail: {
                if let percentage = valuation.gainPercentage {
                    SensitiveValue {
                        Text(VaultFormatters.percentage(percentage, showsPositiveSign: true))
                            .monospacedDigit()
                            .foregroundStyle(performanceColor(percentage))
                            .karaMarketNumericTransition(value: percentage)
                    }
                } else {
                    Text("vault.performance.missing-cost")
                }
            }
        }
    }

    private var inventoryMetricCard: some View {
        Button {
            router.showInventory()
        } label: {
            KaraCard(
                padding: KaraSpacing.medium,
                height: compactMetricCardHeight
            ) {
                KaraMetric(title: "vault.metric.inventory", systemImage: "shippingbox.fill") {
                    SensitiveValue {
                        Text("vault.metric.objects \(valuation.coverage.totalObjectCount)")
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                            .minimumScaleFactor(0.68)
                            .lineLimit(1)
                    }
                } detail: {
                    if valuation.coverage.totalRecordCount
                        != valuation.coverage.totalObjectCount
                    {
                        SensitiveValue {
                            Text("vault.metric.records \(valuation.coverage.totalRecordCount)")
                        }
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
                                        .karaMarketNumericTransition(value: value)
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
                                        .karaMarketNumericTransition(value: share)
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
        ValuationHistoryCard(
            history: valuation.history,
            showsUnknownPurchaseDates: valuation.historyUsesUnknownPurchaseDates
        )
    }

    private var primaryActions: some View {
        Button {
            router.presentAssetCreation()
        } label: {
            Label("vault.action.add", systemImage: "plus")
        }
        .buttonStyle(.karaPrimaryAction)
        .accessibilityIdentifier("home.add")
    }

    private var compactMetricCardHeight: CGFloat? {
        dynamicTypeSize.isAccessibilitySize ? nil : 136
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
                                        .karaMarketNumericTransition(value: value)
                                }
                            }

                            if let share = category.sharePercentage {
                                SensitiveValue {
                                    Text(VaultFormatters.percentage(share))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(theme.goldBright)
                                        .karaMarketNumericTransition(value: share)
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
                size: 52,
                privacyBehavior: .sensitive
            )

            VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                Text(asset.name)
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(LocalizedStringKey(asset.category.localizationKey))
                    let quantity = itemValuation?.quantity ?? asset.quantity
                    if quantity > 1 {
                        SensitiveValue {
                            Text("×\(quantity)")
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
                            .karaMarketNumericTransition(value: value)
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
                            .karaMarketNumericTransition(value: gain)
                    }
                }
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var metalPricesCard: some View {
        KaraCard(padding: KaraSpacing.large) {
            VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                        Text("vault.gold-live.eyebrow")
                            .font(.caption2.weight(.semibold))
                            .textCase(.uppercase)
                            .tracking(1.2)
                            .foregroundStyle(theme.goldBright)

                        Text("vault.market.title")
                            .font(theme.displayFont(size: 21, relativeTo: .title3))
                            .foregroundStyle(theme.ink)
                    }

                    Spacer()

                    if isRefreshing {
                        ProgressView()
                            .tint(theme.goldBright)
                            .accessibilityLabel(Text("vault.market.refreshing"))
                    }
                }

                Picker("vault.market.metal", selection: $selectedMetal) {
                    ForEach(MarketMetal.allCases, id: \.self) { metal in
                        Text(metal.symbol)
                            .accessibilityLabel(Text(LocalizedStringKey(metal.localizationKey)))
                            .tag(metal)
                    }
                }
                .pickerStyle(.segmented)
                .frame(minHeight: 44)
                .tint(theme.goldBright)
                .accessibilityIdentifier("vault.market.metal")

                Group {
                    if let quote = metalQuotes[selectedMetal] {
                        VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                            Text(LocalizedStringKey(selectedMetal.localizationKey))
                                .font(.headline)
                                .foregroundStyle(metalTint(selectedMetal))

                            HStack(alignment: .firstTextBaseline, spacing: KaraSpacing.small) {
                                Text(VaultFormatters.currency(quote.pricePerGram, maximumFractionDigits: 2))
                                    .font(theme.displayFont(size: 31, relativeTo: .title))
                                    .monospacedDigit()
                                    .foregroundStyle(theme.ink)
                                    .karaMarketNumericTransition(value: quote.pricePerGram)

                                Text("vault.gold-live.per-gram")
                                    .font(.subheadline)
                                    .foregroundStyle(theme.muted)
                            }
                            HStack(alignment: .firstTextBaseline) {
                                Text("vault.gold-live.per-ounce \(VaultFormatters.currency(quote.price, maximumFractionDigits: 2))")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(theme.muted)
                                    .karaMarketNumericTransition(value: quote.price)

                                Spacer(minLength: KaraSpacing.small)

                                VStack(alignment: .trailing, spacing: KaraSpacing.xSmall) {
                                    Text(
                                        quote.sourceUpdatedAt,
                                        format: .dateTime.day().month(.abbreviated).hour().minute()
                                    )
                                    .font(.caption2)
                                    .foregroundStyle(theme.muted)

                                    if isUsingCachedMarketData {
                                        Label("vault.market.cached", systemImage: "clock.arrow.circlepath")
                                            .font(.caption2)
                                            .foregroundStyle(theme.goldBright)
                                    }
                                }
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: KaraSpacing.small) {
                            Text(LocalizedStringKey(selectedMetal.localizationKey))
                                .font(.headline)
                                .foregroundStyle(metalTint(selectedMetal))

                            Label("vault.market.unavailable", systemImage: "wifi.exclamationmark")
                                .font(.subheadline)
                                .foregroundStyle(theme.muted)

                            if !isRefreshing {
                                Button("vault.market.retry") {
                                    Task { await refresh() }
                                }
                                .buttonStyle(.glass)
                            }
                        }
                    }
                }
                .id(selectedMetal)
                .transition(.opacity)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: selectedMetal)
            }
        }
        .accessibilityIdentifier("vault.metal-prices")
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

private extension MarketMetal {
    var symbol: String {
        switch self {
        case .gold: "Au"
        case .silver: "Ag"
        case .platinum: "Pt"
        case .palladium: "Pd"
        }
    }

    var localizationKey: String {
        preciousMetal.localizationKey
    }
}
