import SwiftUI

struct AssetCharacteristicsStepView: View {
    private enum FocusField: Hashable {
        case name
        case weight
        case metalKarat
        case fineness
        case gemstoneWeight
        case gemstoneClarity
    }

    @Environment(KaraTheme.self) private var theme

    let state: AssetCreationState
    let onContinue: () -> Void

    @FocusState private var focusedField: FocusField?
    @State private var hasGemstones = false

    var body: some View {
        AssetStepScaffold(
            title: "characteristics.title",
            message: "characteristics.body",
            onDismissKeyboard: dismissKeyboard
        ) {
            if let preset = AssetCatalog.preset(id: state.draft.presetID) {
                presetSummary(preset)
            }

            identitySection

            if state.draft.category == .custom {
                customMetalSection
            }

            if state.draft.metal != nil || state.draft.category != .custom {
                compositionSection
            }

            if state.draft.category == .jewelry {
                gemstoneSection
            }

            validationMessages

            if let issue = state.issue {
                AssetIssueBanner(issue: issue, onDismiss: state.dismissIssue)
            }
        } footer: {
            AssetStepFooter(
                title: "characteristics.continue",
                systemImage: "arrow.right",
                action: validateAndContinue
            )
            .accessibilityIdentifier("characteristics.continue")
        }
        .onAppear {
            hasGemstones = state.draft.gemstoneCaratWeight != nil || !state.draft.gemstoneClarity.isEmpty
        }
        .onChange(of: state.draft.gemstoneCaratWeight) { _, value in
            if value != nil { hasGemstones = true }
        }
        .onChange(of: state.draft.gemstoneClarity) { _, value in
            if !value.isEmpty { hasGemstones = true }
        }
    }

    private func presetSummary(_ preset: AssetPreset) -> some View {
        HStack(spacing: KaraSpacing.medium) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(theme.goldBright)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                Text("characteristics.preset-applied")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.muted)

                Text(localizedName(for: preset))
                    .font(.headline)
                    .foregroundStyle(theme.ink)
            }

            Spacer(minLength: 0)
        }
        .padding(KaraSpacing.medium)
        .background(theme.gold.opacity(0.10), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.medium) {
            AssetSectionTitle("characteristics.identity.title", detail: "characteristics.identity.body")

            AssetFieldSurface {
                VStack(alignment: .leading, spacing: KaraSpacing.small) {
                    AssetFieldLabel("details.name", helper: "characteristics.name.helper")
                    TextField("characteristics.name.placeholder", text: binding(\.name, field: .name))
                        .textInputAutocapitalization(.words)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .name)
                        .onSubmit { focusedField = .weight }
                        .assetInputSurface()
                        .accessibilityIdentifier("details.name")
                }

                Divider()

                Stepper(value: binding(\.quantity, field: .quantity), in: 1 ... 999) {
                    LabeledContent("details.quantity") {
                        Text(state.draft.quantity, format: .number)
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(theme.ink)
                    }
                }
                .accessibilityIdentifier("details.quantity")
            }
        }
    }

    private var customMetalSection: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.medium) {
            AssetSectionTitle("classification.metal.title", detail: "characteristics.custom-metal.helper")

            AssetFieldSurface {
                Picker("details.metal", selection: binding(\.metal, field: .metal)) {
                    Text("details.metal.none")
                        .tag(nil as PreciousMetal?)
                    ForEach(PreciousMetal.allCases, id: \.self) { metal in
                        Text(metal.localizedKey)
                            .tag(Optional(metal))
                    }
                }
                .pickerStyle(.menu)
                .assetPickerSurface()
                .accessibilityIdentifier("details.metal")
            }
        }
    }

    private var compositionSection: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.medium) {
            AssetSectionTitle("characteristics.composition.title", detail: "characteristics.composition.body")

            AssetFieldSurface {
                VStack(alignment: .leading, spacing: KaraSpacing.small) {
                    AssetFieldLabel("characteristics.weight.title", helper: "characteristics.weight.helper")

                    HStack(alignment: .firstTextBaseline, spacing: KaraSpacing.small) {
                        TextField(
                            "characteristics.weight.placeholder",
                            value: binding(\.weightGrams, field: .weightGrams),
                            format: .number.precision(.fractionLength(0 ... 4))
                        )
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .weight)
                        .assetInputSurface()
                        .accessibilityIdentifier("details.weight")

                        Text("characteristics.unit.grams")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(theme.muted)
                    }
                }

                if state.draft.metal == .gold {
                    Divider()
                    goldPurityEditor
                } else if state.draft.metal != nil {
                    Divider()
                    finenessEditor
                }
            }
        }
    }

    private var goldPurityEditor: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.medium) {
            AssetFieldLabel("characteristics.gold-purity.title", helper: "characteristics.gold-purity.helper")

            AssetGoldPurityPicker(selectedKarat: state.draft.metalKarat) { purity in
                state.update(\.metalKarat, to: Optional(purity.karat), field: .metalKarat)
                state.update(\.finenessPermille, to: Optional(purity.fineness), field: .finenessPermille)
            }

            VStack(alignment: .leading, spacing: KaraSpacing.small) {
                AssetFieldLabel(
                    "characteristics.metal-karat.title",
                    helper: "characteristics.metal-karat.helper"
                )

                HStack(alignment: .firstTextBaseline, spacing: KaraSpacing.small) {
                    TextField(
                        "characteristics.metal-karat.placeholder",
                        value: goldKaratBinding,
                        format: .number
                    )
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .metalKarat)
                    .assetInputSurface()
                    .accessibilityIdentifier("details.metal-karat")

                    Text("ct")
                        .font(.headline)
                        .foregroundStyle(theme.muted)
                }
            }

            if let karat = state.draft.metalKarat, let fineness = state.draft.finenessPermille {
                Text("\(karat) ct · \(fineness.formatted(.number.precision(.fractionLength(0 ... 1)))) ‰")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(theme.goldBright)
                    .contentTransition(.numericText())
            }
        }
    }

    private var finenessEditor: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.small) {
            AssetFieldLabel("characteristics.fineness.title", helper: "characteristics.fineness.helper")

            HStack(alignment: .firstTextBaseline, spacing: KaraSpacing.small) {
                TextField(
                    "characteristics.fineness.placeholder",
                    value: binding(\.finenessPermille, field: .finenessPermille),
                    format: .number.precision(.fractionLength(0 ... 2))
                )
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .fineness)
                .assetInputSurface()
                .accessibilityIdentifier("details.fineness")

                Text("‰")
                    .font(.headline)
                    .foregroundStyle(theme.muted)
            }
        }
    }

    private var gemstoneSection: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.medium) {
            AssetSectionTitle("characteristics.gemstones.title", detail: "characteristics.gemstones.body")

            AssetFieldSurface {
                Toggle("characteristics.gemstones.toggle", isOn: gemstonesBinding)
                    .accessibilityIdentifier("characteristics.gemstones.toggle")

                if hasGemstones {
                    Divider()

                    VStack(alignment: .leading, spacing: KaraSpacing.small) {
                        AssetFieldLabel("details.gemstone-carat", helper: "characteristics.gemstone-weight.helper")
                        HStack(alignment: .firstTextBaseline, spacing: KaraSpacing.small) {
                            TextField(
                                "characteristics.gemstone-weight.placeholder",
                                value: binding(\.gemstoneCaratWeight, field: .gemstoneCaratWeight),
                                format: .number.precision(.fractionLength(0 ... 3))
                            )
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .gemstoneWeight)
                            .assetInputSurface()
                            .accessibilityIdentifier("details.gemstone-carat")

                            Text("ct")
                                .font(.headline)
                                .foregroundStyle(theme.muted)
                        }
                    }

                    VStack(alignment: .leading, spacing: KaraSpacing.small) {
                        AssetFieldLabel("details.gemstone-clarity", helper: "characteristics.gemstone-clarity.helper")
                        TextField(
                            "characteristics.gemstone-clarity.placeholder",
                            text: binding(\.gemstoneClarity, field: .gemstoneClarity)
                        )
                        .textInputAutocapitalization(.characters)
                        .focused($focusedField, equals: .gemstoneClarity)
                        .assetInputSurface()
                        .accessibilityIdentifier("details.gemstone-clarity")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var validationMessages: some View {
        if state.validationAttempted, !characteristicValidationErrors.isEmpty {
            AssetFieldSurface {
                ForEach(characteristicValidationErrors, id: \.self) { error in
                    Label(validationKey(for: error), systemImage: "exclamationmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
            }
            .accessibilityIdentifier("details.validation-errors")
        }
    }

    private var characteristicValidationErrors: [AssetDraftValidationError] {
        state.draft.validationErrors.filter {
            switch $0 {
            case .missingName, .missingCategory, .invalidQuantity, .invalidWeight,
                 .invalidMetalKarat, .invalidFineness, .invalidGemstoneCaratWeight:
                true
            case .invalidPrice, .invalidCurrencyCode:
                false
            }
        }
    }

    private var gemstonesBinding: Binding<Bool> {
        Binding(
            get: { hasGemstones },
            set: { enabled in
                hasGemstones = enabled
                guard !enabled else { return }
                state.update(\.gemstoneCaratWeight, to: nil, field: .gemstoneCaratWeight)
                state.update(\.gemstoneClarity, to: "", field: .gemstoneClarity)
            }
        )
    }

    private var goldKaratBinding: Binding<Int?> {
        Binding(
            get: { state.draft.metalKarat },
            set: { karat in
                state.update(\.metalKarat, to: karat, field: .metalKarat)
                state.update(
                    \.finenessPermille,
                    to: karat.flatMap(fineness(for:)),
                    field: .finenessPermille
                )
            }
        )
    }

    private func fineness(for karat: Int) -> Double? {
        guard (1 ... 24).contains(karat) else { return nil }
        return AssetGoldPurity.common.first(where: { $0.karat == karat })?.fineness
            ?? Double(karat) / 24 * 1_000
    }

    private func validateAndContinue() {
        guard state.validateDraft() else {
            focusedField = state.draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .name : nil
            return
        }
        focusedField = nil
        onContinue()
    }

    private func dismissKeyboard() {
        focusedField = nil
    }

    private func localizedName(for preset: AssetPreset) -> String {
        let resource = LocalizedStringResource(String.LocalizationValue(preset.localizationKey))
        let localized = String(localized: resource)
        return localized == preset.localizationKey ? preset.name : localized
    }

    private func binding<Value>(
        _ keyPath: WritableKeyPath<AssetDraft, Value>,
        field: AssetDraft.Field
    ) -> Binding<Value> {
        Binding(
            get: { state.draft[keyPath: keyPath] },
            set: { state.update(keyPath, to: $0, field: field) }
        )
    }

    private func validationKey(for error: AssetDraftValidationError) -> LocalizedStringKey {
        switch error {
        case .missingName: "details.validation.missing-name"
        case .missingCategory: "details.validation.missing-category"
        case .invalidQuantity: "details.validation.invalid-quantity"
        case .invalidWeight: "details.validation.invalid-weight"
        case .invalidMetalKarat: "details.validation.invalid-metal-karat"
        case .invalidFineness: "details.validation.invalid-fineness"
        case .invalidGemstoneCaratWeight: "details.validation.invalid-gemstone-carat"
        case .invalidPrice: "details.validation.invalid-price"
        case .invalidCurrencyCode: "details.validation.invalid-currency"
        }
    }
}
