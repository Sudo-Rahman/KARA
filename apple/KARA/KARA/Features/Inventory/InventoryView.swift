import SwiftUI

struct InventoryView: View {
    @Environment(AppRouter.self) private var router
    @Environment(KaraTheme.self) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let assets: [Asset]
    let attachments: [AssetAttachment]
    let valuation: PortfolioValuation
    let isRefreshing: Bool
    let repository: any AssetTrashManaging

    @State private var searchText = ""
    @State private var selectedMetal: PreciousMetal?
    @State private var selectedCategory: AssetCategory?
    @State private var sortOption = InventorySortOption.recent
    @State private var deletionRequest: AssetDeletionRequest?
    @State private var isShowingDeletionConfirmation = false
    @State private var isShowingDeletionError = false

    var body: some View {
        let renderData = InventoryRenderData(
            valuation: valuation,
            attachments: attachments
        )
        let visibleAssets = filteredAssets(values: renderData.inventoryValues)

        ScrollView {
            LazyVStack(alignment: .leading, spacing: KaraSpacing.medium) {
                filters
                summaryCard

                if visibleAssets.isEmpty {
                    noResults
                } else {
                    HStack {
                        SensitiveValue {
                            Text("inventory.results \(visibleAssets.count)")
                                .font(.caption.weight(.semibold))
                                .textCase(.uppercase)
                                .tracking(1.1)
                                .foregroundStyle(theme.muted)
                        }

                        Spacer()

                        if hasActiveFilters {
                            Button("inventory.filters.reset") {
                                selectedMetal = nil
                                selectedCategory = nil
                                searchText = ""
                            }
                            .font(.caption.weight(.semibold))
                        }
                    }

                    ForEach(visibleAssets) { asset in
                        Button {
                            router.showAsset(asset.id)
                        } label: {
                            inventoryRow(
                                asset,
                                valuation: renderData.assetValuations[asset.id],
                                photoData: renderData.objectPhotoData[asset.id]
                            )
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("asset-delete.action.delete", role: .destructive) {
                                requestDeletion(of: asset)
                            }
                            .accessibilityIdentifier("inventory.asset.delete.\(asset.id.uuidString)")
                        } onPresentationChanged: { _ in }
                        .contextMenu {
                            Button {
                                router.presentEditor(for: asset.id)
                            } label: {
                                Label("asset-detail.action.edit", systemImage: "pencil")
                            }
                            .accessibilityIdentifier("inventory.asset.edit.\(asset.id.uuidString)")

                            Divider()

                            Button(role: .destructive) {
                                requestDeletion(of: asset)
                            } label: {
                                Label("asset-delete.action.delete", systemImage: "trash")
                            }
                            .accessibilityIdentifier("inventory.asset.delete.\(asset.id.uuidString)")
                        }
                        .accessibilityIdentifier("inventory.asset.\(asset.id.uuidString)")
                    }
                }
            }
            .padding(.horizontal, KaraSpacing.medium)
            .padding(.top, KaraSpacing.small)
            .padding(.bottom, KaraSpacing.xxLarge)
        }
        .scrollIndicators(.hidden)
        .swipeActionsContainer()
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("inventory.title")
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text("inventory.search.prompt")
        )
        .assetDeletionPresentation(
            request: $deletionRequest,
            isPresentingConfirmation: $isShowingDeletionConfirmation,
            isShowingError: $isShowingDeletionError,
            delete: repository.moveToTrash
        )
        .accessibilityIdentifier("inventory.screen")
    }

    private var filters: some View {
        ScrollView(.horizontal) {
            HStack(spacing: KaraSpacing.small) {
                Menu {
                    Button("inventory.filter.all-metals") {
                        selectedMetal = nil
                    }

                    Divider()

                    ForEach(PreciousMetal.allCases, id: \.self) { metal in
                        Button {
                            selectedMetal = metal
                        } label: {
                            if selectedMetal == metal {
                                Label {
                                    Text(metal.localizedKey)
                                } icon: {
                                    Image(systemName: "checkmark")
                                }
                            } else {
                                Text(metal.localizedKey)
                            }
                        }
                    }
                } label: {
                    InventoryFilterChip(
                        title: selectedMetal?.localizedKey ?? "inventory.filter.all-metals",
                        systemImage: "circle.hexagongrid.fill",
                        isActive: selectedMetal != nil
                    )
                }

                Menu {
                    Button("inventory.filter.all-categories") {
                        selectedCategory = nil
                    }

                    Divider()

                    ForEach(AssetCategory.allCases, id: \.self) { category in
                        Button {
                            selectedCategory = category
                        } label: {
                            if selectedCategory == category {
                                Label {
                                    Text(LocalizedStringKey(category.localizationKey))
                                } icon: {
                                    Image(systemName: "checkmark")
                                }
                            } else {
                                Text(LocalizedStringKey(category.localizationKey))
                            }
                        }
                    }
                } label: {
                    InventoryFilterChip(
                        title: selectedCategory.map { LocalizedStringKey($0.localizationKey) }
                            ?? "inventory.filter.all-categories",
                        systemImage: "square.grid.2x2.fill",
                        isActive: selectedCategory != nil
                    )
                }

                Menu {
                    ForEach(InventorySortOption.allCases) { option in
                        Button {
                            sortOption = option
                        } label: {
                            if sortOption == option {
                                Label {
                                    Text(LocalizedStringKey(option.localizationKey))
                                } icon: {
                                    Image(systemName: "checkmark")
                                }
                            } else {
                                Text(LocalizedStringKey(option.localizationKey))
                            }
                        }
                    }
                } label: {
                    InventoryFilterChip(
                        title: LocalizedStringKey(sortOption.localizationKey),
                        systemImage: "arrow.up.arrow.down",
                        isActive: sortOption != .recent
                    )
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var summaryCard: some View {
        KaraCard(padding: KaraSpacing.large) {
            VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                HStack(alignment: .firstTextBaseline) {
                    Text("inventory.summary.eyebrow")
                        .font(.caption2.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(theme.goldBright)

                    Spacer()

                    SensitiveValue {
                        Text("inventory.summary.objects \(valuation.coverage.totalObjectCount)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(theme.muted)
                    }
                }

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                        summaryEstimatedValue
                        summaryGain(alignment: .leading)
                    }
                } else {
                    HStack(alignment: .lastTextBaseline) {
                        summaryEstimatedValue
                        Spacer(minLength: KaraSpacing.small)
                        summaryGain(alignment: .trailing)
                    }
                }

                if valuation.coverage.valuedRecordCount < valuation.coverage.totalRecordCount {
                    Label("inventory.summary.partial", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(theme.goldBright)
                }

                if valuation.coverage.performanceRecordCount < valuation.coverage.valuedRecordCount {
                    SensitiveValue {
                        Text("vault.performance.partial \(valuation.coverage.performanceRecordCount) \(valuation.coverage.valuedRecordCount)")
                            .font(.caption)
                            .foregroundStyle(theme.goldBright)
                    }
                }
            }
        }
    }

    private var noResults: some View {
        ContentUnavailableView {
            Label(
                assets.isEmpty
                    ? LocalizedStringKey("inventory.empty.title")
                    : LocalizedStringKey("inventory.no-results.title"),
                systemImage: assets.isEmpty ? "shippingbox" : "magnifyingglass"
            )
        } description: {
            Text(assets.isEmpty
                ? LocalizedStringKey("inventory.empty.body")
                : LocalizedStringKey("inventory.no-results.body"))
        } actions: {
            if assets.isEmpty {
                Button("inventory.empty.add") {
                    router.presentAssetCreation()
                }
                .buttonStyle(.glassProminent)
            } else {
                Button("inventory.filters.reset") {
                    selectedMetal = nil
                    selectedCategory = nil
                    searchText = ""
                }
                .buttonStyle(.glass)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .foregroundStyle(theme.ink)
    }

    @ViewBuilder
    private var summaryEstimatedValue: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
            Text("inventory.summary.total")
                .font(.subheadline)
                .foregroundStyle(theme.muted)

            if valuation.coverage.valuedRecordCount > 0 {
                SensitiveValue {
                    Text(VaultFormatters.currency(valuation.totalEstimatedValueEUR))
                        .font(theme.displayFont(size: 30, relativeTo: .title))
                        .monospacedDigit()
                        .foregroundStyle(theme.ink)
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
                    .font(theme.displayFont(size: 30, relativeTo: .title))
                    .foregroundStyle(theme.muted)
            }
        }
    }

    @ViewBuilder
    private func summaryGain(alignment: HorizontalAlignment) -> some View {
        if let gain = valuation.totalGainEUR {
            VStack(alignment: alignment, spacing: KaraSpacing.xSmall) {
                Text("inventory.summary.gain")
                    .font(.caption)
                    .foregroundStyle(theme.muted)

                SensitiveValue {
                    Text(VaultFormatters.currency(gain, showsPositiveSign: true))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(performanceColor(gain))
                }
            }
        }
    }

    private func inventoryRow(
        _ asset: Asset,
        valuation item: AssetValuation?,
        photoData: Data?
    ) -> some View {
        KaraCard(padding: KaraSpacing.medium) {
            HStack(spacing: KaraSpacing.medium) {
                AssetArtworkView(
                    category: asset.category,
                    photoData: photoData,
                    size: 62
                )

                VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                    Text(asset.name)
                        .font(.headline)
                        .foregroundStyle(theme.ink)
                        .lineLimit(2)

                    HStack(spacing: 5) {
                        if let metal = asset.metal {
                            Text(metal.localizedKey)
                        }

                        if let fineWeight = item?.fineWeightGrams {
                            Text("·")
                            SensitiveValue {
                                Text(VaultFormatters.weight(fineWeight))
                                    .monospacedDigit()
                            }
                        }

                        if asset.quantity > 1 {
                            Text("·")
                            SensitiveValue {
                                Text("×\(asset.quantity)")
                                    .monospacedDigit()
                            }
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(theme.muted)
                    .lineLimit(1)
                }

                Spacer(minLength: KaraSpacing.xSmall)

                VStack(alignment: .trailing, spacing: KaraSpacing.xSmall) {
                    if let value = item?.estimatedValueEUR {
                        SensitiveValue {
                            Text(VaultFormatters.currency(value))
                                .font(.headline.monospacedDigit())
                                .foregroundStyle(theme.ink)
                        }
                    } else {
                        Image(systemName: "exclamationmark.circle")
                            .foregroundStyle(theme.goldBright)
                            .accessibilityLabel(Text("inventory.asset.unvalued"))
                    }

                    if let gain = item?.gainPercentage {
                        SensitiveValue {
                            Text(VaultFormatters.percentage(gain, showsPositiveSign: true))
                                .font(.caption.weight(.semibold).monospacedDigit())
                                .foregroundStyle(performanceColor(gain))
                        }
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.muted)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private func filteredAssets(values: [UUID: InventoryValue]) -> [Asset] {
        let matching = assets.filter {
            InventoryQuery.matches(
                $0,
                searchText: searchText,
                metal: selectedMetal,
                category: selectedCategory
            )
        }
        return InventoryQuery.sorted(matching, by: sortOption, values: values)
    }

    private var hasActiveFilters: Bool {
        !searchText.isEmpty || selectedMetal != nil || selectedCategory != nil
    }

    private func performanceColor(_ value: Decimal) -> Color {
        if value > 0 { return .green }
        if value < 0 { return .red }
        return theme.muted
    }

    private func requestDeletion(of asset: Asset) {
        deletionRequest = AssetDeletionRequest(id: asset.id, name: asset.name)
        isShowingDeletionConfirmation = true
    }
}

private struct InventoryRenderData {
    let assetValuations: [UUID: AssetValuation]
    let inventoryValues: [UUID: InventoryValue]
    let objectPhotoData: [UUID: Data]

    init(
        valuation: PortfolioValuation,
        attachments: [AssetAttachment]
    ) {
        var valuationsByAssetID: [UUID: AssetValuation] = [:]
        var inventoryValuesByAssetID: [UUID: InventoryValue] = [:]

        for item in valuation.assetValuations {
            valuationsByAssetID[item.assetID] = item
            inventoryValuesByAssetID[item.assetID] = InventoryValue(
                estimatedValueEUR: item.estimatedValueEUR,
                gainPercentage: item.gainPercentage
            )
        }

        var latestPhotosByAssetID: [UUID: AssetAttachment] = [:]
        for attachment in attachments where attachment.kind == .objectPhoto {
            if let existing = latestPhotosByAssetID[attachment.assetID],
               existing.createdAt >= attachment.createdAt {
                continue
            }
            latestPhotosByAssetID[attachment.assetID] = attachment
        }

        assetValuations = valuationsByAssetID
        inventoryValues = inventoryValuesByAssetID
        objectPhotoData = latestPhotosByAssetID.mapValues { $0.data }
    }
}

private struct InventoryFilterChip: View {
    @Environment(KaraTheme.self) private var theme

    let title: LocalizedStringKey
    let systemImage: String
    let isActive: Bool

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(isActive ? theme.ink : theme.muted)
            .padding(.horizontal, 12)
            .frame(minHeight: 38)
            .background(
                isActive ? theme.cobalt.opacity(0.22) : theme.surface,
                in: .capsule
            )
            .overlay {
                Capsule()
                    .stroke(
                        isActive ? theme.cobaltBright.opacity(0.55) : theme.muted.opacity(0.20),
                        lineWidth: 1
                    )
            }
    }
}
