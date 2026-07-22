import SwiftUI

struct AssetClassificationStepView: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let state: AssetCreationState
    let onContinue: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: KaraSpacing.small),
        GridItem(.flexible(), spacing: KaraSpacing.small),
    ]

    var body: some View {
        AssetStepScaffold(
            title: "classification.title",
            message: "classification.body"
        ) {
            if state.objectAnalysisPhase == .completed || state.invoiceAnalysisPhase == .completed {
                Label("classification.ai-prefill", systemImage: "apple.intelligence")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.goldBright)
                    .padding(.horizontal, KaraSpacing.medium)
                    .padding(.vertical, 10)
                    .background(theme.gold.opacity(0.10), in: .capsule)
            }

            AssetSectionTitle("classification.category.title")

            LazyVGrid(columns: columns, spacing: KaraSpacing.small) {
                ForEach(AssetCategory.allCases, id: \.self) { category in
                    AssetCategoryCard(
                        category: category,
                        isSelected: state.draft.category == category,
                        action: { select(category) }
                    )
                }
            }
            .accessibilityIdentifier("classification.categories")

            if state.draft.category != nil, state.draft.category != .custom {
                metalSelection
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if !filteredPresets.isEmpty {
                presetSelection
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        } footer: {
            AssetStepFooter(
                title: "classification.continue",
                systemImage: "arrow.right",
                isEnabled: canContinue,
                action: onContinue
            )
            .accessibilityIdentifier("classification.continue")
        }
        .animation(KaraMotion.controlResponse(reduceMotion: reduceMotion), value: state.draft.category)
        .animation(KaraMotion.controlResponse(reduceMotion: reduceMotion), value: state.draft.metal)
    }

    private var metalSelection: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.medium) {
            AssetSectionTitle("classification.metal.title")

            ScrollView(.horizontal) {
                HStack(spacing: KaraSpacing.small) {
                    ForEach(PreciousMetal.allCases, id: \.self) { metal in
                        Button {
                            select(metal)
                        } label: {
                            Label(metal.localizedKey, systemImage: metal.symbolName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(state.draft.metal == metal ? theme.ink : theme.muted)
                                .padding(.horizontal, KaraSpacing.medium)
                                .frame(minHeight: 44)
                                .background(
                                    state.draft.metal == metal
                                        ? theme.cobalt.opacity(0.24)
                                        : theme.surface,
                                    in: .capsule
                                )
                                .overlay {
                                    Capsule()
                                        .stroke(
                                            state.draft.metal == metal
                                                ? theme.cobaltBright.opacity(0.85)
                                                : Color.clear,
                                            lineWidth: state.draft.metal == metal ? 1.5 : 1
                                        )
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(state.draft.metal == metal ? .isSelected : [])
                        .accessibilityIdentifier("classification.metal.\(metal.rawValue)")
                    }
                }
                .padding(.horizontal, 1)
                .padding(.vertical, KaraSpacing.xSmall)
            }
            .assetPageHorizontalCarousel()
            .scrollIndicators(.hidden)
        }
        .accessibilityIdentifier("classification.metals")
    }

    private var presetSelection: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.medium) {
            AssetSectionTitle("classification.preset.title")

            ScrollView(.horizontal) {
                LazyHStack(spacing: KaraSpacing.small) {
                    ForEach(filteredPresets) { preset in
                        AssetPresetCard(
                            preset: preset,
                            name: localizedName(for: preset),
                            isSelected: state.draft.presetID == preset.id,
                            action: {
                                state.applyPreset(preset, localizedName: localizedName(for: preset))
                            }
                        )
                        .containerRelativeFrame(.horizontal, count: 2, spacing: KaraSpacing.small)
                    }
                }
                .padding(.horizontal, 1)
                .padding(.vertical, KaraSpacing.xSmall)
                .scrollTargetLayout()
            }
            .assetPageHorizontalCarousel()
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.viewAligned)
            .accessibilityIdentifier("classification.presets")
        }
    }

    private var filteredPresets: [AssetPreset] {
        guard let category = state.draft.category else { return [] }
        return AssetCatalog.presets(category: category, metal: state.draft.metal)
            .filter { !$0.isCustomEntry }
    }

    private var canContinue: Bool {
        state.draft.category != nil
    }

    private func select(_ category: AssetCategory) {
        if let preset = AssetCatalog.preset(id: state.draft.presetID), preset.category != category {
            state.clearPresetSelection()
        }

        state.update(\.category, to: Optional(category), field: .category)

        if category == .custom {
            state.clearPresetSelection()
            state.update(\.metal, to: nil, field: .metal)
        }
    }

    private func select(_ metal: PreciousMetal) {
        if let preset = AssetCatalog.preset(id: state.draft.presetID), preset.metal != metal {
            state.clearPresetSelection()
        }

        state.update(\.metal, to: Optional(metal), field: .metal)
    }

    private func localizedName(for preset: AssetPreset) -> String {
        let resource = LocalizedStringResource(String.LocalizationValue(preset.localizationKey))
        let localized = String(localized: resource)
        return localized == preset.localizationKey ? preset.name : localized
    }
}

private extension View {
    func assetPageHorizontalCarousel() -> some View {
        contentMargins(.horizontal, KaraSpacing.large, for: .scrollContent)
            .padding(.horizontal, -KaraSpacing.large)
    }
}

private struct AssetCategoryCard: View {
    @Environment(KaraTheme.self) private var theme

    let category: AssetCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: KaraSpacing.small) {
                Image(category.imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 12))
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(theme.background, theme.goldBright)
                                .padding(KaraSpacing.small)
                        }
                    }
                    .accessibilityHidden(true)

                Text(LocalizedStringKey(category.localizationKey))
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(KaraSpacing.small)
            .background(theme.surface, in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? theme.goldBright : .clear, lineWidth: 1.5)
            }
            .contentShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("classification.category.\(category.rawValue)")
    }
}

private struct AssetPresetCard: View {
    @Environment(KaraTheme.self) private var theme

    let preset: AssetPreset
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: KaraSpacing.small) {
                HStack {
                    Image(systemName: preset.category.symbolName)
                        .foregroundStyle(theme.goldBright)
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(theme.goldBright)
                    }
                }

                Text(name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.ink)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                if let weight = preset.weightGrams {
                    Text("\(weight.formatted(.number.precision(.fractionLength(0 ... 3)))) g")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(theme.muted)
                }
            }
            .padding(KaraSpacing.medium)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
            .background(theme.surface, in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? theme.cobaltBright : theme.muted.opacity(0.16),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("classification.preset.\(preset.id)")
    }
}
