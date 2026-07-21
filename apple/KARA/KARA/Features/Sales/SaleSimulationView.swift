import SwiftUI

struct SaleSimulationView: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let assets: [Asset]
    let attachments: [AssetAttachment]
    let valuation: PortfolioValuation

    @State private var selectedQuantities: [UUID: Int] = [:]

    var body: some View {
        let renderData = SaleSimulationRenderData(
            assets: assets,
            attachments: attachments,
            valuation: valuation
        )
        let currentTotals = totals(for: renderData)

        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: KaraSpacing.large) {
                    introduction
                    totalsCard(currentTotals)

                    if renderData.valuedAssets.isEmpty {
                        unavailableState
                    } else {
                        selectionHeader(totals: currentTotals)

                        ForEach(renderData.valuedAssets) { asset in
                            assetSelectionRow(
                                asset,
                                valuation: renderData.assetValuations[asset.id],
                                photoData: renderData.objectPhotoData[asset.id]
                            )
                        }

                        disclaimer
                    }
                }
                .padding(.horizontal, KaraSpacing.medium)
                .padding(.top, KaraSpacing.small)
                .padding(.bottom, KaraSpacing.xxLarge)
            }
            .scrollIndicators(.hidden)
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("sale-simulation.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("sale-simulation.close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    PrivacyToolbarButton()
                }
            }
        }
        .accessibilityIdentifier("sale-simulation.screen")
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.small) {
            Text("sale-simulation.eyebrow")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(1.4)
                .foregroundStyle(theme.goldBright)

            Text("sale-simulation.heading")
                .font(theme.displayFont(size: 29, relativeTo: .largeTitle))
                .foregroundStyle(theme.ink)

            Text("sale-simulation.body")
                .font(.subheadline)
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func totalsCard(_ totals: SaleSimulationTotals) -> some View {
        KaraCard(padding: KaraSpacing.large) {
            VStack(alignment: .leading, spacing: KaraSpacing.large) {
                HStack(alignment: .firstTextBaseline) {
                    Text("sale-simulation.total.eyebrow")
                        .font(.caption2.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(theme.goldBright)

                    Spacer()

                    SensitiveValue {
                        Text("sale-simulation.total.objects \(totals.selectedObjectCount)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(theme.muted)
                    }
                }

                SensitiveValue {
                    Text(VaultFormatters.currency(totals.estimatedProceedsEUR))
                        .font(theme.displayFont(size: 36, relativeTo: .largeTitle))
                        .monospacedDigit()
                        .foregroundStyle(theme.ink)
                        .contentTransition(.numericText())
                }

                totalMetrics(totals)
            }
        }
    }

    @ViewBuilder
    private func totalMetrics(_ totals: SaleSimulationTotals) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                totalCostMetric(totals)
                totalGainMetric(totals)
                totalPerformanceMetric(totals)
            }
        } else {
            HStack(alignment: .top, spacing: KaraSpacing.large) {
                totalCostMetric(totals)
                totalGainMetric(totals)
                totalPerformanceMetric(totals)
            }
        }
    }

    private func totalCostMetric(_ totals: SaleSimulationTotals) -> some View {
        simulationMetric(
            title: "sale-simulation.total.cost",
            value: totals.purchaseCostEUR.map { VaultFormatters.currency($0) },
            tint: theme.ink
        )
    }

    private func totalGainMetric(_ totals: SaleSimulationTotals) -> some View {
        simulationMetric(
            title: "sale-simulation.total.gain",
            value: totals.estimatedGainEUR.map {
                VaultFormatters.currency($0, showsPositiveSign: true)
            },
            tint: totals.estimatedGainEUR.map(performanceColor) ?? theme.muted
        )
    }

    private func totalPerformanceMetric(_ totals: SaleSimulationTotals) -> some View {
        simulationMetric(
            title: "sale-simulation.total.performance",
            value: totals.gainPercentage.map {
                VaultFormatters.percentage($0, showsPositiveSign: true)
            },
            tint: totals.gainPercentage.map(performanceColor) ?? theme.muted
        )
    }

    private func simulationMetric(
        title: LocalizedStringKey,
        value: String?,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(theme.muted)

            if let value {
                SensitiveValue {
                    Text(value)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(tint)
                        .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 0.82 : 0.65)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                }
            } else {
                Text("sale-simulation.value.unavailable")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func selectionHeader(totals: SaleSimulationTotals) -> some View {
        HStack(alignment: .lastTextBaseline) {
            VaultSectionHeader("sale-simulation.selection.title", eyebrow: "sale-simulation.selection.eyebrow")

            Spacer(minLength: KaraSpacing.small)

            if totals.selectedObjectCount > 0 {
                Button("sale-simulation.selection.clear") {
                    selectedQuantities.removeAll()
                }
                .font(.caption.weight(.semibold))
            }
        }
    }

    private func assetSelectionRow(
        _ asset: Asset,
        valuation item: AssetValuation?,
        photoData: Data?
    ) -> some View {
        let selected = selectedQuantities[asset.id, default: 0]

        return KaraCard(padding: KaraSpacing.medium) {
            VStack(spacing: KaraSpacing.medium) {
                HStack(spacing: KaraSpacing.medium) {
                    Button {
                        selectedQuantities[asset.id] = selected == 0 ? 1 : 0
                    } label: {
                        Image(systemName: selected > 0 ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(selected > 0 ? theme.cobaltBright : theme.muted)
                    }
                    .accessibilityLabel(Text(LocalizedStringKey(
                        selected > 0
                            ? "sale-simulation.asset.deselect"
                            : "sale-simulation.asset.select"
                    )))

                    AssetArtworkView(
                        category: asset.category,
                        photoData: photoData,
                        size: 54
                    )

                    VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                        Text(asset.name)
                            .font(.headline)
                            .foregroundStyle(theme.ink)
                            .lineLimit(2)

                        if let value = item?.estimatedValueEUR {
                            SensitiveValue {
                                Text(VaultFormatters.currency(value))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(theme.muted)
                            }
                        }
                    }

                    Spacer(minLength: KaraSpacing.xSmall)
                }

                quantitySelector(for: asset, selected: selected)
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func quantitySelector(for asset: Asset, selected: Int) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: KaraSpacing.small) {
                quantityLabel

                HStack(spacing: KaraSpacing.medium) {
                    quantityControls(for: asset, selected: selected)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        } else {
            HStack(spacing: KaraSpacing.medium) {
                quantityLabel
                Spacer()
                quantityControls(for: asset, selected: selected)
            }
        }
    }

    private var quantityLabel: some View {
        Text("sale-simulation.asset.quantity")
            .font(.caption)
            .foregroundStyle(theme.muted)
    }

    @ViewBuilder
    private func quantityControls(for asset: Asset, selected: Int) -> some View {
        Button {
            setQuantity(selected - 1, for: asset)
        } label: {
            Image(systemName: "minus")
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.glass)
        .disabled(selected == 0)
        .accessibilityLabel(Text("sale-simulation.quantity.decrease"))

        SensitiveValue {
            Text("\(selected) / \(asset.quantity)")
                .font(.headline.monospacedDigit())
                .frame(minWidth: 64)
                .contentTransition(.numericText())
        }

        Button {
            setQuantity(selected + 1, for: asset)
        } label: {
            Image(systemName: "plus")
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.glass)
        .disabled(selected >= asset.quantity)
        .accessibilityLabel(Text("sale-simulation.quantity.increase"))
    }

    private var unavailableState: some View {
        ContentUnavailableView {
            Label("sale-simulation.unavailable.title", systemImage: "equal.circle")
        } description: {
            Text("sale-simulation.unavailable.body")
        }
        .foregroundStyle(theme.ink)
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private var disclaimer: some View {
        Label("sale-simulation.disclaimer", systemImage: "info.circle")
            .font(.caption)
            .foregroundStyle(theme.muted)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, KaraSpacing.small)
    }

    private func simulationLines(for renderData: SaleSimulationRenderData) -> [SaleSimulationLine] {
        renderData.valuedAssets.compactMap { asset in
            guard let item = renderData.assetValuations[asset.id],
                  let value = item.estimatedValueEUR else {
                return nil
            }
            return SaleSimulationLine(
                assetID: asset.id,
                selectedQuantity: selectedQuantities[asset.id, default: 0],
                availableQuantity: asset.quantity,
                estimatedValueEUR: value,
                purchaseCostEUR: item.purchaseCostEUR
            )
        }
    }

    private func totals(for renderData: SaleSimulationRenderData) -> SaleSimulationTotals {
        SaleSimulationCalculator.totals(for: simulationLines(for: renderData))
    }

    private func setQuantity(_ quantity: Int, for asset: Asset) {
        selectedQuantities[asset.id] = min(max(0, quantity), asset.quantity)
    }

    private func performanceColor(_ value: Decimal) -> Color {
        if value > 0 { return .green }
        if value < 0 { return .red }
        return theme.muted
    }
}

private struct SaleSimulationRenderData {
    let valuedAssets: [Asset]
    let assetValuations: [UUID: AssetValuation]
    let objectPhotoData: [UUID: Data]

    init(
        assets: [Asset],
        attachments: [AssetAttachment],
        valuation: PortfolioValuation
    ) {
        var valuationsByAssetID: [UUID: AssetValuation] = [:]
        for item in valuation.assetValuations {
            valuationsByAssetID[item.assetID] = item
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
        objectPhotoData = latestPhotosByAssetID.mapValues { $0.data }
        valuedAssets = assets
            .filter { valuationsByAssetID[$0.id]?.estimatedValueEUR != nil && $0.quantity > 0 }
            .sorted { $0.createdAt > $1.createdAt }
    }
}
