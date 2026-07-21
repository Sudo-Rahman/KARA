import Foundation
import SwiftUI

nonisolated struct AssetEditorDraftState: Equatable, Sendable {
    let originalDraft: AssetDraft
    var draft: AssetDraft

    init(draft: AssetDraft) {
        originalDraft = draft
        self.draft = draft
    }

    var hasUnsavedChanges: Bool {
        draft != originalDraft
    }

    var priceAmount: Decimal? {
        get {
            draft.pricePaidMinorUnits.flatMap {
                MoneyConverter.decimalAmount(
                    from: $0,
                    currencyCode: draft.currencyCode
                )
            }
        }
        set {
            draft.pricePaidMinorUnits = newValue.flatMap {
                MoneyConverter.minorUnits(
                    from: $0,
                    currencyCode: draft.currencyCode
                )
            }
        }
    }

    mutating func setTags(from text: String) {
        let separators = CharacterSet(charactersIn: ",;\n")
        draft.tags = AssetTagNormalizer.normalize(
            text.components(separatedBy: separators)
        )
    }

    mutating func setCurrency(_ currency: SupportedAssetCurrency) {
        let amount = priceAmount
        draft.currencyCode = currency.rawValue
        priceAmount = amount
    }

    mutating func apply(preset: AssetPreset, displayName: String) {
        draft.apply(preset: preset)
        draft.name = displayName
    }

    mutating func setCategory(_ category: AssetCategory) {
        draft.category = category
        detachIncompatiblePreset()
    }

    mutating func setMetal(_ metal: PreciousMetal?) {
        draft.metal = metal
        detachIncompatiblePreset()
    }

    private mutating func detachIncompatiblePreset() {
        guard let preset = AssetCatalog.preset(id: draft.presetID) else { return }
        let categoryMatches = preset.category == draft.category
        let metalMatches = preset.metal == nil || preset.metal == draft.metal
        if !categoryMatches || !metalMatches {
            draft.presetID = nil
        }
    }
}

@MainActor
struct AssetEditorView: View {
    private enum FocusField: Hashable {
        case name
        case weight
        case karat
        case fineness
        case price
        case seller
        case storage
        case invoice
        case serialNumber
        case tags
        case gemstoneWeight
        case gemstoneClarity
    }

    @Environment(KaraTheme.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    private let assetID: UUID
    private let repository: any AssetUpdating

    @State private var editor: AssetEditorDraftState
    @State private var tagsText: String
    @State private var validationAttempted = false
    @State private var isSaving = false
    @State private var showingDiscardConfirmation = false
    @State private var showingSaveError = false
    @FocusState private var focusedField: FocusField?

    init(asset: Asset, repository: any AssetUpdating) {
        let draft = AssetDraft(asset: asset)
        assetID = asset.id
        self.repository = repository
        _editor = State(initialValue: AssetEditorDraftState(draft: draft))
        _tagsText = State(initialValue: draft.tags.joined(separator: ", "))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: KaraSpacing.large) {
                    introduction
                    identitySection
                    compositionSection
                    purchaseSection
                    inventorySection
                    gemstoneSection

                    if validationAttempted, !editor.draft.validationErrors.isEmpty {
                        validationSection
                    }
                }
                .padding(.horizontal, KaraSpacing.large)
                .padding(.top, KaraSpacing.medium)
                .padding(.bottom, KaraSpacing.xxLarge)
            }
            .background(theme.background.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(AssetEditorCopy.string("asset-editor.title"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: requestDismissal) {
                        AssetEditorCopy.text("asset-editor.action.cancel")
                    }
                    .accessibilityIdentifier("asset-editor.cancel")
                }

                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        focusedField = nil
                    } label: {
                        AssetEditorCopy.text("asset-editor.action.keyboard-done")
                    }
                }
            }
            .safeAreaBar(edge: .bottom, spacing: 0) {
                saveBar
            }
            .interactiveDismissDisabled(editor.hasUnsavedChanges)
            .confirmationDialog(
                AssetEditorCopy.string("asset-editor.discard.title"),
                isPresented: $showingDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button(
                    AssetEditorCopy.string("asset-editor.discard.action"),
                    role: .destructive,
                    action: dismiss.callAsFunction
                )
                Button(
                    AssetEditorCopy.string("asset-editor.discard.keep-editing"),
                    role: .cancel
                ) {}
            } message: {
                AssetEditorCopy.text("asset-editor.discard.message")
            }
            .alert(
                AssetEditorCopy.string("asset-editor.save-error.title"),
                isPresented: $showingSaveError
            ) {
                Button(AssetEditorCopy.string("asset-editor.action.ok"), role: .cancel) {}
            } message: {
                AssetEditorCopy.text("asset-editor.save-error.message")
            }
        }
    }

    private var introduction: some View {
        HStack(alignment: .top, spacing: KaraSpacing.medium) {
            Image(systemName: "square.and.pencil")
                .font(.title2.weight(.semibold))
                .foregroundStyle(theme.goldBright)
                .frame(width: 48, height: 48)
                .background(theme.gold.opacity(0.12), in: .circle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                AssetEditorCopy.text("asset-editor.introduction.title")
                    .font(theme.displayFont(size: 24, relativeTo: .title2))
                    .foregroundStyle(theme.ink)
                    .accessibilityAddTraits(.isHeader)

                AssetEditorCopy.text("asset-editor.introduction.body")
                    .font(.subheadline)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var identitySection: some View {
        AssetEditorSection(
            title: "asset-editor.section.identity.title",
            message: "asset-editor.section.identity.body",
            systemImage: "seal"
        ) {
            AssetEditorField(
                title: "asset-editor.field.name",
                helper: "asset-editor.field.name.helper"
            ) {
                TextField(
                    AssetEditorCopy.string("asset-editor.field.name.placeholder"),
                    text: binding(\.name)
                )
                .textInputAutocapitalization(.words)
                .submitLabel(.next)
                .focused($focusedField, equals: .name)
                .onSubmit { focusedField = .weight }
                .assetEditorInputSurface()
                .accessibilityLabel(AssetEditorCopy.string("asset-editor.field.name"))
                .accessibilityIdentifier("asset-editor.name")
            }

            editorDivider

            Picker(
                AssetEditorCopy.string("asset-editor.field.category"),
                selection: categoryBinding
            ) {
                ForEach(AssetCategory.allCases, id: \.self) { category in
                    Text(LocalizedStringKey(category.localizationKey))
                        .tag(category)
                }
            }
            .pickerStyle(.menu)
            .assetEditorPickerSurface()
            .accessibilityIdentifier("asset-editor.category")

            if !availablePresets.isEmpty {
                editorDivider

                AssetEditorField(
                    title: "asset-editor.field.preset",
                    helper: "asset-editor.field.preset.helper"
                ) {
                    Picker(
                        AssetEditorCopy.string("asset-editor.field.preset"),
                        selection: presetBinding
                    ) {
                        AssetEditorCopy.text("asset-editor.field.preset.none")
                            .tag(Optional<String>.none)

                        ForEach(availablePresets) { preset in
                            Text(localizedName(for: preset))
                                .tag(Optional(preset.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .assetEditorPickerSurface()
                    .accessibilityIdentifier("asset-editor.preset")
                }
            }

            editorDivider

            Stepper(value: binding(\.quantity), in: 1 ... 999) {
                LabeledContent(AssetEditorCopy.string("asset-editor.field.quantity")) {
                    Text(editor.draft.quantity, format: .number)
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(theme.ink)
                        .contentTransition(.numericText())
                }
            }
            .accessibilityIdentifier("asset-editor.quantity")
        }
    }

    private var compositionSection: some View {
        AssetEditorSection(
            title: "asset-editor.section.composition.title",
            message: "asset-editor.section.composition.body",
            systemImage: "atom"
        ) {
            Picker(
                AssetEditorCopy.string("asset-editor.field.metal"),
                selection: metalBinding
            ) {
                AssetEditorCopy.text("asset-editor.field.metal.none")
                    .tag(Optional<PreciousMetal>.none)

                ForEach(PreciousMetal.allCases, id: \.self) { metal in
                    Text(LocalizedStringKey(metal.localizationKey))
                        .tag(Optional(metal))
                }
            }
            .pickerStyle(.menu)
            .assetEditorPickerSurface()
            .accessibilityIdentifier("asset-editor.metal")

            editorDivider

            AssetEditorField(
                title: "asset-editor.field.weight",
                helper: "asset-editor.field.weight.helper"
            ) {
                measurementField(
                    label: "asset-editor.field.weight",
                    placeholder: "asset-editor.field.weight.placeholder",
                    value: binding(\.weightGrams),
                    format: .number.precision(.fractionLength(0 ... 4)),
                    unit: "g",
                    keyboard: .decimalPad,
                    focus: .weight,
                    identifier: "asset-editor.weight"
                )
            }

            if editor.draft.metal == .gold {
                editorDivider
                commonGoldPurities
            }

            editorDivider

            AssetEditorField(
                title: "asset-editor.field.karat",
                helper: "asset-editor.field.karat.helper"
            ) {
                HStack(alignment: .firstTextBaseline, spacing: KaraSpacing.small) {
                    TextField(
                        AssetEditorCopy.string("asset-editor.field.karat.placeholder"),
                        value: binding(\.metalKarat),
                        format: .number
                    )
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .karat)
                    .assetEditorInputSurface()
                    .accessibilityLabel(AssetEditorCopy.string("asset-editor.field.karat"))
                    .accessibilityIdentifier("asset-editor.karat")

                    Text("ct")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(theme.muted)
                }
            }

            editorDivider

            AssetEditorField(
                title: "asset-editor.field.fineness",
                helper: "asset-editor.field.fineness.helper"
            ) {
                measurementField(
                    label: "asset-editor.field.fineness",
                    placeholder: "asset-editor.field.fineness.placeholder",
                    value: binding(\.finenessPermille),
                    format: .number.precision(.fractionLength(0 ... 2)),
                    unit: "‰",
                    keyboard: .decimalPad,
                    focus: .fineness,
                    identifier: "asset-editor.fineness"
                )
            }
        }
    }

    private var purchaseSection: some View {
        AssetEditorSection(
            title: "asset-editor.section.purchase.title",
            message: "asset-editor.section.purchase.body",
            systemImage: "eurosign.circle"
        ) {
            Toggle(
                AssetEditorCopy.string("asset-editor.field.purchase-date-known"),
                isOn: purchaseDateEnabledBinding
            )
            .accessibilityIdentifier("asset-editor.purchase-date-toggle")

            if editor.draft.purchaseDate != nil {
                DatePicker(
                    AssetEditorCopy.string("asset-editor.field.purchase-date"),
                    selection: purchaseDateBinding,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .accessibilityIdentifier("asset-editor.purchase-date")
            }

            editorDivider

            AssetEditorField(
                title: "asset-editor.field.price",
                helper: "asset-editor.field.price.helper"
            ) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: KaraSpacing.small) {
                        priceField
                        currencyPicker
                    }

                    VStack(alignment: .leading, spacing: KaraSpacing.small) {
                        priceField
                        currencyPicker
                    }
                }
            }

            editorDivider

            Picker(
                AssetEditorCopy.string("asset-editor.field.acquisition-method"),
                selection: binding(\.acquisitionMethod)
            ) {
                AssetEditorCopy.text("asset-editor.field.acquisition-method.unknown")
                    .tag(Optional<AssetAcquisitionMethod>.none)

                ForEach(AssetAcquisitionMethod.allCases) { method in
                    Text(LocalizedStringKey(method.localizationKey))
                        .tag(Optional(method))
                }
            }
            .pickerStyle(.menu)
            .assetEditorPickerSurface()
            .accessibilityIdentifier("asset-editor.acquisition-method")

            editorDivider

            AssetEditorField(
                title: "asset-editor.field.seller",
                helper: "asset-editor.field.seller.helper"
            ) {
                TextField(
                    AssetEditorCopy.string("asset-editor.field.seller.placeholder"),
                    text: binding(\.sellerName)
                )
                .textInputAutocapitalization(.words)
                .focused($focusedField, equals: .seller)
                .assetEditorInputSurface()
                .accessibilityLabel(AssetEditorCopy.string("asset-editor.field.seller"))
                .accessibilityIdentifier("asset-editor.seller")
            }
        }
    }

    private var inventorySection: some View {
        AssetEditorSection(
            title: "asset-editor.section.inventory.title",
            message: "asset-editor.section.inventory.body",
            systemImage: "lock.doc"
        ) {
            AssetEditorField(
                title: "asset-editor.field.storage",
                helper: "asset-editor.field.storage.helper"
            ) {
                TextField(
                    AssetEditorCopy.string("asset-editor.field.storage.placeholder"),
                    text: binding(\.storageLocationName)
                )
                .textInputAutocapitalization(.words)
                .focused($focusedField, equals: .storage)
                .assetEditorInputSurface()
                .accessibilityLabel(AssetEditorCopy.string("asset-editor.field.storage"))
                .accessibilityIdentifier("asset-editor.storage")
            }

            editorDivider

            AssetEditorField(
                title: "asset-editor.field.invoice",
                helper: "asset-editor.field.invoice.helper"
            ) {
                TextField(
                    AssetEditorCopy.string("asset-editor.field.invoice.placeholder"),
                    text: binding(\.invoiceNumber)
                )
                .textInputAutocapitalization(.characters)
                .focused($focusedField, equals: .invoice)
                .assetEditorInputSurface()
                .accessibilityLabel(AssetEditorCopy.string("asset-editor.field.invoice"))
                .accessibilityIdentifier("asset-editor.invoice")
            }

            editorDivider

            AssetEditorField(
                title: "asset-editor.field.serial-number",
                helper: "asset-editor.field.serial-number.helper"
            ) {
                TextField(
                    AssetEditorCopy.string("asset-editor.field.serial-number.placeholder"),
                    text: binding(\.serialNumber)
                )
                .textInputAutocapitalization(.characters)
                .focused($focusedField, equals: .serialNumber)
                .assetEditorInputSurface()
                .accessibilityLabel(AssetEditorCopy.string("asset-editor.field.serial-number"))
                .accessibilityIdentifier("asset-editor.serial-number")
            }

            editorDivider

            AssetEditorField(
                title: "asset-editor.field.tags",
                helper: "asset-editor.field.tags.helper"
            ) {
                TextField(
                    AssetEditorCopy.string("asset-editor.field.tags.placeholder"),
                    text: $tagsText,
                    axis: .vertical
                )
                .lineLimit(1 ... 3)
                .textInputAutocapitalization(.sentences)
                .focused($focusedField, equals: .tags)
                .assetEditorInputSurface()
                .accessibilityLabel(AssetEditorCopy.string("asset-editor.field.tags"))
                .accessibilityIdentifier("asset-editor.tags")
                .onChange(of: tagsText) { _, value in
                    editor.setTags(from: value)
                }
            }
        }
    }

    private var gemstoneSection: some View {
        AssetEditorSection(
            title: "asset-editor.section.gemstones.title",
            message: "asset-editor.section.gemstones.body",
            systemImage: "diamond"
        ) {
            AssetEditorField(
                title: "asset-editor.field.gemstone-weight",
                helper: "asset-editor.field.gemstone-weight.helper"
            ) {
                measurementField(
                    label: "asset-editor.field.gemstone-weight",
                    placeholder: "asset-editor.field.gemstone-weight.placeholder",
                    value: binding(\.gemstoneCaratWeight),
                    format: .number.precision(.fractionLength(0 ... 3)),
                    unit: "ct",
                    keyboard: .decimalPad,
                    focus: .gemstoneWeight,
                    identifier: "asset-editor.gemstone-weight"
                )
            }

            editorDivider

            AssetEditorField(
                title: "asset-editor.field.gemstone-clarity",
                helper: "asset-editor.field.gemstone-clarity.helper"
            ) {
                TextField(
                    AssetEditorCopy.string("asset-editor.field.gemstone-clarity.placeholder"),
                    text: binding(\.gemstoneClarity)
                )
                .textInputAutocapitalization(.characters)
                .focused($focusedField, equals: .gemstoneClarity)
                .assetEditorInputSurface()
                .accessibilityLabel(AssetEditorCopy.string("asset-editor.field.gemstone-clarity"))
                .accessibilityIdentifier("asset-editor.gemstone-clarity")
            }
        }
    }

    private var validationSection: some View {
        KaraCard {
            VStack(alignment: .leading, spacing: KaraSpacing.small) {
                Label {
                    AssetEditorCopy.text("asset-editor.validation.title")
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(.headline)
                .foregroundStyle(.red)

                ForEach(editor.draft.validationErrors, id: \.self) { error in
                    Label {
                        validationMessage(for: error)
                    } icon: {
                        Image(systemName: "exclamationmark.circle.fill")
                    }
                    .font(.subheadline)
                    .foregroundStyle(theme.ink)
                }
            }
        }
        .accessibilityIdentifier("asset-editor.validation-errors")
    }

    private var saveBar: some View {
        Button(action: save) {
            HStack(spacing: KaraSpacing.small) {
                if isSaving {
                    ProgressView()
                } else {
                    Image(systemName: "checkmark.seal.fill")
                        .accessibilityHidden(true)
                }

                AssetEditorCopy.text(
                    isSaving ? "asset-editor.action.saving" : "asset-editor.action.save"
                )
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.karaPrimaryAction(isLoading: isSaving))
        .disabled(isSaving || !editor.hasUnsavedChanges)
        .accessibilityIdentifier("asset-editor.save")
        .padding(.horizontal, KaraSpacing.large)
        .padding(.vertical, KaraSpacing.small)
        .background(theme.background)
    }

    private var editorDivider: some View {
        Divider()
            .overlay(theme.muted.opacity(0.18))
    }

    private var commonGoldPurities: some View {
        AssetEditorField(
            title: "asset-editor.field.quick-purity",
            helper: "asset-editor.field.quick-purity.helper"
        ) {
            ScrollView(.horizontal) {
                HStack(spacing: KaraSpacing.small) {
                    ForEach(Self.commonGoldPurities, id: \.karat) { purity in
                        Button {
                            editor.draft.metalKarat = purity.karat
                            editor.draft.finenessPermille = purity.fineness
                        } label: {
                            Text("\(purity.karat) ct")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(
                                    editor.draft.metalKarat == purity.karat
                                        ? theme.ink
                                        : theme.muted
                                )
                                .padding(.horizontal, KaraSpacing.medium)
                                .frame(minHeight: 44)
                                .background(
                                    editor.draft.metalKarat == purity.karat
                                        ? theme.cobalt.opacity(0.28)
                                        : theme.background.opacity(0.76),
                                    in: .capsule
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(
                            editor.draft.metalKarat == purity.karat ? .isSelected : []
                        )
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var priceField: some View {
        TextField(
            AssetEditorCopy.string("asset-editor.field.price.placeholder"),
            value: priceAmountBinding,
            format: .number.precision(.fractionLength(0 ... 2))
        )
        .keyboardType(.decimalPad)
        .focused($focusedField, equals: .price)
        .assetEditorInputSurface()
        .accessibilityLabel(AssetEditorCopy.string("asset-editor.field.price"))
        .accessibilityIdentifier("asset-editor.price")
    }

    private var currencyPicker: some View {
        Picker(
            AssetEditorCopy.string("asset-editor.field.currency"),
            selection: currencyBinding
        ) {
            ForEach(SupportedAssetCurrency.allCases) { currency in
                Text(currencyLabel(currency))
                    .tag(currency)
            }
        }
        .pickerStyle(.menu)
        .assetEditorPickerSurface()
        .accessibilityIdentifier("asset-editor.currency")
    }

    private var categoryBinding: Binding<AssetCategory> {
        Binding(
            get: { editor.draft.category ?? .custom },
            set: { editor.setCategory($0) }
        )
    }

    private var metalBinding: Binding<PreciousMetal?> {
        Binding(
            get: { editor.draft.metal },
            set: { editor.setMetal($0) }
        )
    }

    private var presetBinding: Binding<String?> {
        Binding(
            get: { editor.draft.presetID },
            set: { presetID in
                guard let preset = AssetCatalog.preset(id: presetID) else {
                    editor.draft.presetID = nil
                    return
                }
                editor.apply(preset: preset, displayName: localizedName(for: preset))
            }
        )
    }

    private var purchaseDateEnabledBinding: Binding<Bool> {
        Binding(
            get: { editor.draft.purchaseDate != nil },
            set: { enabled in
                editor.draft.purchaseDate = enabled
                    ? (editor.draft.purchaseDate ?? Date())
                    : nil
            }
        )
    }

    private var purchaseDateBinding: Binding<Date> {
        Binding(
            get: { editor.draft.purchaseDate ?? Date() },
            set: { editor.draft.purchaseDate = $0 }
        )
    }

    private var priceAmountBinding: Binding<Decimal?> {
        Binding(
            get: { editor.priceAmount },
            set: { editor.priceAmount = $0 }
        )
    }

    private var currencyBinding: Binding<SupportedAssetCurrency> {
        Binding(
            get: {
                SupportedAssetCurrency(rawValue: editor.draft.currencyCode)
                    ?? .defaultCurrency
            },
            set: { editor.setCurrency($0) }
        )
    }

    private var availablePresets: [AssetPreset] {
        guard let category = editor.draft.category else { return [] }

        var result = AssetCatalog.presets.filter { preset in
            !preset.isCustomEntry
                && preset.category == category
                && (editor.draft.metal == nil || preset.metal == editor.draft.metal)
        }

        if let current = AssetCatalog.preset(id: editor.draft.presetID),
           !current.isCustomEntry,
           !result.contains(where: { $0.id == current.id }) {
            result.append(current)
        }

        return result
    }

    private func binding<Value>(
        _ keyPath: WritableKeyPath<AssetDraft, Value>
    ) -> Binding<Value> {
        Binding(
            get: { editor.draft[keyPath: keyPath] },
            set: { editor.draft[keyPath: keyPath] = $0 }
        )
    }

    private func measurementField(
        label: String.LocalizationValue,
        placeholder: String.LocalizationValue,
        value: Binding<Double?>,
        format: FloatingPointFormatStyle<Double>,
        unit: String,
        keyboard: UIKeyboardType,
        focus: FocusField,
        identifier: String
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: KaraSpacing.small) {
            TextField(
                AssetEditorCopy.string(placeholder),
                value: value,
                format: format
            )
            .keyboardType(keyboard)
            .focused($focusedField, equals: focus)
            .assetEditorInputSurface()
            .accessibilityLabel(AssetEditorCopy.string(label))
            .accessibilityIdentifier(identifier)

            Text(unit)
                .font(.headline.monospacedDigit())
                .foregroundStyle(theme.muted)
        }
    }

    private func requestDismissal() {
        focusedField = nil
        if editor.hasUnsavedChanges {
            showingDiscardConfirmation = true
        } else {
            dismiss()
        }
    }

    private func save() {
        validationAttempted = true
        guard editor.draft.isValid else {
            focusFirstInvalidField()
            return
        }

        focusedField = nil
        isSaving = true
        defer { isSaving = false }

        do {
            try repository.update(assetID: assetID, with: editor.draft)
            dismiss()
        } catch {
            showingSaveError = true
        }
    }

    private func focusFirstInvalidField() {
        let focus: FocusField?
        if editor.draft.validationErrors.contains(.missingName) {
            focus = .name
        } else if editor.draft.validationErrors.contains(.invalidWeight) {
            focus = .weight
        } else if editor.draft.validationErrors.contains(.invalidMetalKarat) {
            focus = .karat
        } else if editor.draft.validationErrors.contains(.invalidFineness) {
            focus = .fineness
        } else if editor.draft.validationErrors.contains(.invalidGemstoneCaratWeight) {
            focus = .gemstoneWeight
        } else if editor.draft.validationErrors.contains(.invalidPrice) {
            focus = .price
        } else {
            focus = nil
        }

        if reduceMotion {
            focusedField = focus
        } else {
            withAnimation(.easeOut(duration: KaraMotion.reducedDuration)) {
                focusedField = focus
            }
        }
    }

    private func validationMessage(
        for error: AssetDraftValidationError
    ) -> Text {
        let key: String
        switch error {
        case .missingName: key = "asset-editor.validation.missing-name"
        case .missingCategory: key = "asset-editor.validation.missing-category"
        case .invalidQuantity: key = "asset-editor.validation.invalid-quantity"
        case .invalidWeight: key = "asset-editor.validation.invalid-weight"
        case .invalidMetalKarat: key = "asset-editor.validation.invalid-karat"
        case .invalidFineness: key = "asset-editor.validation.invalid-fineness"
        case .invalidGemstoneCaratWeight: key = "asset-editor.validation.invalid-gemstone-weight"
        case .invalidPrice: key = "asset-editor.validation.invalid-price"
        case .invalidCurrencyCode: key = "asset-editor.validation.invalid-currency"
        }
        return AssetEditorCopy.text(String.LocalizationValue(key))
    }

    private func localizedName(for preset: AssetPreset) -> String {
        let resource = LocalizedStringResource(
            String.LocalizationValue(preset.localizationKey)
        )
        let localized = String(localized: resource)
        return localized == preset.localizationKey ? preset.name : localized
    }

    private func currencyLabel(_ currency: SupportedAssetCurrency) -> String {
        switch currency {
        case .euro: "€  EUR"
        case .usDollar: "$  USD"
        case .swissFranc: "CHF"
        case .poundSterling: "£  GBP"
        }
    }

    private static let commonGoldPurities: [(karat: Int, fineness: Double)] = [
        (24, 999.9),
        (22, 916.7),
        (18, 750),
        (14, 585),
        (9, 375),
    ]
}

private struct AssetEditorSection<Content: View>: View {
    @Environment(KaraTheme.self) private var theme

    let title: String.LocalizationValue
    let message: String.LocalizationValue
    let systemImage: String
    @ViewBuilder let content: Content

    init(
        title: String.LocalizationValue,
        message: String.LocalizationValue,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.medium) {
            HStack(alignment: .firstTextBaseline, spacing: KaraSpacing.small) {
                Image(systemName: systemImage)
                    .font(.headline)
                    .foregroundStyle(theme.goldBright)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                    AssetEditorCopy.text(title)
                        .font(.headline)
                        .foregroundStyle(theme.ink)
                        .accessibilityAddTraits(.isHeader)

                    AssetEditorCopy.text(message)
                        .font(.subheadline)
                        .foregroundStyle(theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            KaraCard {
                VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                    content
                }
            }
        }
    }
}

private struct AssetEditorField<Content: View>: View {
    @Environment(KaraTheme.self) private var theme

    let title: String.LocalizationValue
    let helper: String.LocalizationValue?
    @ViewBuilder let content: Content

    init(
        title: String.LocalizationValue,
        helper: String.LocalizationValue? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.helper = helper
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.small) {
            VStack(alignment: .leading, spacing: 2) {
                AssetEditorCopy.text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.ink)

                if let helper {
                    AssetEditorCopy.text(helper)
                        .font(.caption)
                        .foregroundStyle(theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
        }
    }
}

private enum AssetEditorCopy {
    static func resource(
        _ key: String.LocalizationValue
    ) -> LocalizedStringResource {
        LocalizedStringResource(key, table: "AssetEditor")
    }

    static func string(_ key: String.LocalizationValue) -> String {
        String(localized: resource(key))
    }

    static func text(_ key: String.LocalizationValue) -> Text {
        Text(resource(key))
    }
}

private struct AssetEditorInputSurface: ViewModifier {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    func body(content: Content) -> some View {
        content
            .font(.body)
            .padding(.horizontal, 12)
            .frame(minHeight: 48)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        reduceTransparency
                            ? theme.background
                            : theme.cobalt.opacity(0.12)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        theme.cobaltBright.opacity(
                            colorSchemeContrast == .increased ? 0.52 : 0.22
                        ),
                        lineWidth: colorSchemeContrast == .increased ? 1.5 : 1
                    )
                    .allowsHitTesting(false)
            }
    }
}

private extension View {
    func assetEditorInputSurface() -> some View {
        modifier(AssetEditorInputSurface())
    }

    func assetEditorPickerSurface() -> some View {
        modifier(AssetEditorInputSurface())
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Asset editor") {
    let asset = Asset(
        name: "Lingotin 20 g",
        category: .bar,
        presetID: "gold-bar-20g",
        purchaseDate: Date(timeIntervalSince1970: 1_715_731_200),
        metal: .gold,
        weightGrams: 20,
        metalKarat: 24,
        finenessPermille: 999.9,
        pricePaidMinorUnits: 2_850_00,
        currencyCode: "EUR",
        sellerName: "Comptoir des métaux précieux",
        storageLocationName: "Coffre principal",
        invoiceNumber: "FAC-2024-0515",
        serialNumber: "A123456",
        acquisitionMethod: .purchase,
        tags: ["Investissement", "Long terme"]
    )

    AssetEditorView(
        asset: asset,
        repository: PreviewAssetUpdater(asset: asset)
    )
    .environment(KaraTheme())
    .preferredColorScheme(.dark)
}

#Preview("Asset editor — jewelry · accessibility text") {
    let asset = Asset(
        name: "Bracelet ancien 18 ct",
        category: .jewelry,
        quantity: 1,
        metal: .gold,
        weightGrams: 12.6,
        metalKarat: 18,
        finenessPermille: 750,
        gemstoneCaratWeight: 0.65,
        gemstoneClarity: "VS1",
        currencyCode: "EUR",
        acquisitionMethod: .inheritance,
        tags: ["Héritage familial"]
    )

    AssetEditorView(
        asset: asset,
        repository: PreviewAssetUpdater(asset: asset)
    )
    .environment(KaraTheme())
    .dynamicTypeSize(.accessibility2)
    .preferredColorScheme(.dark)
}

@MainActor
private struct PreviewAssetUpdater: AssetUpdating {
    let asset: Asset

    func update(assetID: UUID, with draft: AssetDraft) throws -> Asset {
        asset
    }
}
