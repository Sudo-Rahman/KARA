import Foundation
import SwiftData
import SwiftUI

struct AssetPurchaseStepView: View {
    private enum FocusField: Hashable {
        case price
        case seller
        case storage
        case invoiceNumber
        case serialNumber
        case tags
    }

    @Environment(KaraTheme.self) private var theme
    @Query(sort: \SavedSeller.lastUsedAt, order: .reverse) private var sellers: [SavedSeller]
    @Query(sort: \StorageLocation.lastUsedAt, order: .reverse) private var storageLocations: [StorageLocation]

    let state: AssetCreationState
    let onContinue: () -> Void

    @FocusState private var focusedField: FocusField?
    @State private var tagsText: String

    init(state: AssetCreationState, onContinue: @escaping () -> Void) {
        self.state = state
        self.onContinue = onContinue
        _tagsText = State(initialValue: "")
    }

    var body: some View {
        AssetStepScaffold(
            title: "purchase.title",
            message: "purchase.body",
            onDismissKeyboard: dismissKeyboard
        ) {
            purchaseSection
            provenanceSection
            inventorySection

            if state.validationAttempted, !purchaseValidationErrors.isEmpty {
                validationMessages
            }

            if let issue = state.issue {
                AssetIssueBanner(issue: issue, onDismiss: state.dismissIssue)
            }
        } footer: {
            AssetStepFooter(
                title: "purchase.continue",
                systemImage: "arrow.right",
                action: validateAndContinue
            ) {
                Text("purchase.optional-note")
                    .font(.caption)
                    .foregroundStyle(theme.muted)
                    .multilineTextAlignment(.center)
            }
            .accessibilityIdentifier("purchase.continue")
        }
        .onChange(of: focusedField) { oldValue, newValue in
            guard oldValue == .tags, newValue != .tags else { return }
            commitPendingTag()
        }
    }

    private var purchaseSection: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.medium) {
            AssetSectionTitle("purchase.details.title")

            AssetFieldSurface {
                Toggle("details.purchase-date-known", isOn: purchaseDateEnabledBinding)
                    .accessibilityIdentifier("details.purchase-date-toggle")

                if state.draft.purchaseDate != nil {
                    DatePicker(
                        "details.purchase-date",
                        selection: purchaseDateBinding,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .accessibilityIdentifier("details.purchase-date")
                }

                Divider()

                VStack(alignment: .leading, spacing: KaraSpacing.small) {
                    AssetFieldLabel("details.price", helper: "purchase.price.helper")

                    HStack(spacing: KaraSpacing.small) {
                        TextField(
                            "purchase.price.placeholder",
                            value: priceAmountBinding,
                            format: .number.precision(.fractionLength(0 ... 2))
                        )
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .price)
                        .karaPurchaseInputSurface()
                        .accessibilityIdentifier("details.price")

                        Picker("details.currency", selection: currencyBinding) {
                            ForEach(SupportedAssetCurrency.allCases) { currency in
                                Text(currencyLabel(currency))
                                    .tag(currency)
                            }
                        }
                        .pickerStyle(.menu)
                        .fixedSize()
                        .frame(minHeight: 46)
                        .padding(.horizontal, KaraSpacing.small)
                        .background(theme.cobalt.opacity(0.16), in: .rect(cornerRadius: 12))
                        .accessibilityIdentifier("details.currency")
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: KaraSpacing.small) {
                    AssetFieldLabel("details.invoice-number", helper: "purchase.invoice-number.helper")
                    TextField(
                        "purchase.invoice-number.placeholder",
                        text: binding(\.invoiceNumber, field: .invoiceNumber)
                    )
                    .textInputAutocapitalization(.characters)
                    .focused($focusedField, equals: .invoiceNumber)
                    .karaPurchaseInputSurface()
                    .accessibilityIdentifier("details.invoice-number")
                }
            }
        }
    }

    private var provenanceSection: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.medium) {
            AssetSectionTitle("purchase.provenance.title")

            AssetFieldSurface {
                SavedValueComboBox(
                    title: "details.seller",
                    helper: "purchase.seller.helper",
                    placeholder: "purchase.seller.placeholder",
                    text: binding(\.sellerName, field: .sellerName),
                    savedValues: sellers.map { SavedValue(id: $0.id, name: $0.name) },
                    menuTitle: "purchase.seller.saved",
                    accessibilityIdentifier: "details.seller",
                    focusedField: $focusedField,
                    focusValue: .seller
                )

                Divider()

                SavedValueComboBox(
                    title: "details.storage-location",
                    helper: "purchase.storage.helper",
                    placeholder: "purchase.storage.placeholder",
                    text: binding(\.storageLocationName, field: .storageLocationName),
                    savedValues: storageLocations.map { SavedValue(id: $0.id, name: $0.name) },
                    menuTitle: "purchase.storage.saved",
                    accessibilityIdentifier: "details.storage-location",
                    focusedField: $focusedField,
                    focusValue: .storage
                )
            }
        }
    }

    private var inventorySection: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.medium) {
            AssetSectionTitle("purchase.inventory.title")

            AssetFieldSurface {
                VStack(alignment: .leading, spacing: KaraSpacing.small) {
                    AssetFieldLabel("details.acquisition-method")
                    Picker("details.acquisition-method", selection: acquisitionMethodBinding) {
                        Text("purchase.acquisition.unknown")
                            .tag(Optional<AssetAcquisitionMethod>.none)
                        ForEach(AssetAcquisitionMethod.allCases) { method in
                            Text(LocalizedStringKey(method.localizationKey))
                                .tag(Optional(method))
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
                    .padding(.horizontal, 12)
                    .background(theme.cobalt.opacity(0.16), in: .rect(cornerRadius: 12))
                    .accessibilityIdentifier("details.acquisition-method")
                }

                Divider()

                VStack(alignment: .leading, spacing: KaraSpacing.small) {
                    AssetFieldLabel("details.serial-number", helper: "purchase.serial-number.helper")
                    TextField(
                        "purchase.serial-number.placeholder",
                        text: binding(\.serialNumber, field: .serialNumber)
                    )
                    .textInputAutocapitalization(.characters)
                    .focused($focusedField, equals: .serialNumber)
                    .karaPurchaseInputSurface()
                    .accessibilityIdentifier("details.serial-number")
                }

                Divider()

                VStack(alignment: .leading, spacing: KaraSpacing.small) {
                    AssetFieldLabel("details.tags", helper: "purchase.tags.helper")
                    tagsInput
                }
            }
        }
    }

    private var validationMessages: some View {
        AssetFieldSurface {
            ForEach(purchaseValidationErrors, id: \.self) { error in
                Label(validationKey(for: error), systemImage: "exclamationmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }
        }
        .accessibilityIdentifier("purchase.validation-errors")
    }

    private var purchaseValidationErrors: [AssetDraftValidationError] {
        state.draft.validationErrors.filter {
            switch $0 {
            case .invalidPrice, .invalidCurrencyCode:
                true
            default:
                false
            }
        }
    }

    private var purchaseDateEnabledBinding: Binding<Bool> {
        Binding(
            get: { state.draft.purchaseDate != nil },
            set: { isEnabled in
                state.update(
                    \.purchaseDate,
                    to: isEnabled ? (state.draft.purchaseDate ?? Date()) : nil,
                    field: .purchaseDate
                )
            }
        )
    }

    private var purchaseDateBinding: Binding<Date> {
        Binding(
            get: { state.draft.purchaseDate ?? Date() },
            set: { state.update(\.purchaseDate, to: $0, field: .purchaseDate) }
        )
    }

    private var priceAmountBinding: Binding<Decimal?> {
        Binding(
            get: {
                state.draft.pricePaidMinorUnits.flatMap {
                    MoneyConverter.decimalAmount(from: $0, currencyCode: state.draft.currencyCode)
                }
            },
            set: { amount in
                state.update(
                    \.pricePaidMinorUnits,
                    to: amount.flatMap {
                        MoneyConverter.minorUnits(from: $0, currencyCode: state.draft.currencyCode)
                    },
                    field: .pricePaidMinorUnits
                )
            }
        )
    }

    private var currencyBinding: Binding<SupportedAssetCurrency> {
        Binding(
            get: { SupportedAssetCurrency(rawValue: state.draft.currencyCode) ?? .defaultCurrency },
            set: { state.updateCurrencyCode($0.rawValue) }
        )
    }

    private var acquisitionMethodBinding: Binding<AssetAcquisitionMethod?> {
        binding(\.acquisitionMethod, field: .acquisitionMethod)
    }

    private var tagsInput: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.small) {
            if !state.draft.tags.isEmpty {
                TagFlowLayout(horizontalSpacing: KaraSpacing.small, verticalSpacing: KaraSpacing.small) {
                    ForEach(state.draft.tags, id: \.self) { tag in
                        TagChip(tag: tag) {
                            removeTag(tag)
                        }
                    }
                }
            }

            HStack(spacing: KaraSpacing.small) {
                TextField("purchase.tags.placeholder", text: $tagsText)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .focused($focusedField, equals: .tags)
                    .frame(minHeight: 46)
                    .accessibilityIdentifier("details.tags")
                    .onSubmit {
                        commitPendingTag()
                        focusedField = nil
                    }
                    .onChange(of: tagsText) { _, value in
                        commitTagsBeforeSeparator(in: value)
                    }

                if !tagsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        commitPendingTag()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.goldBright)
                    .frame(width: 32, height: 32)
                    .accessibilityLabel("purchase.tags.commit")
                    .accessibilityIdentifier("details.tags.commit")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, KaraSpacing.xSmall)
        .background(Color.black.opacity(0.24), in: .rect(cornerRadius: 12))
    }

    private func commitTagsBeforeSeparator(in value: String) {
        let components = value.components(separatedBy: CharacterSet(charactersIn: ",;\n"))
        guard components.count > 1 else { return }

        let pending = value.last.map { ",;\n".contains($0) ? "" : (components.last ?? "") } ?? ""
        commitTags(Array(components.dropLast()))
        tagsText = pending
    }

    private func commitPendingTag() {
        commitTags([tagsText])
        tagsText = ""
    }

    private func commitTags(_ candidates: [String]) {
        let newTags = AssetTagNormalizer.normalize(candidates)
        guard !newTags.isEmpty else { return }
        state.update(
            \.tags,
            to: AssetTagNormalizer.normalize(state.draft.tags + newTags),
            field: .tags
        )
    }

    private func removeTag(_ tag: String) {
        state.update(
            \.tags,
            to: state.draft.tags.filter { $0 != tag },
            field: .tags
        )
    }

    private func validateAndContinue() {
        commitPendingTag()
        guard state.validateDraft() else {
            if purchaseValidationErrors.contains(.invalidPrice) {
                focusedField = .price
            }
            return
        }
        focusedField = nil
        onContinue()
    }

    private func dismissKeyboard() {
        commitPendingTag()
        focusedField = nil
    }

    private func currencyLabel(_ currency: SupportedAssetCurrency) -> String {
        switch currency {
        case .euro: "€  EUR"
        case .usDollar: "$  USD"
        case .swissFranc: "CHF"
        case .poundSterling: "£  GBP"
        }
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
        case .invalidPrice: "details.validation.invalid-price"
        case .invalidCurrencyCode: "details.validation.invalid-currency"
        default: "asset-flow.error.save"
        }
    }
}

private struct TagChip: View {
    @Environment(KaraTheme.self) private var theme

    let tag: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: KaraSpacing.xSmall) {
            Text(verbatim: tag)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.ink)
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 24, height: 24)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.muted)
            .accessibilityLabel("purchase.tags.remove")
            .accessibilityValue(Text(verbatim: tag))
            .accessibilityIdentifier("details.tags.remove.\(tag)")
        }
        .padding(.leading, 12)
        .padding(.trailing, KaraSpacing.xSmall)
        .background(theme.cobalt.opacity(0.22), in: .capsule)
        .overlay {
            Capsule()
                .stroke(theme.cobaltBright.opacity(0.42), lineWidth: 1)
        }
    }
}

private struct TagFlowLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let availableWidth = proposal.width ?? .greatestFiniteMagnitude
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var widestRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let proposedRowWidth = rowWidth == 0
                ? size.width
                : rowWidth + horizontalSpacing + size.width

            if rowWidth > 0, proposedRowWidth > availableWidth {
                totalHeight += rowHeight + verticalSpacing
                widestRow = max(widestRow, rowWidth)
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth = proposedRowWidth
                rowHeight = max(rowHeight, size.height)
            }
        }

        totalHeight += rowHeight
        widestRow = max(widestRow, rowWidth)
        return CGSize(width: proposal.width ?? widestRow, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: x + size.width / 2, y: y + size.height / 2),
                anchor: .center,
                proposal: ProposedViewSize(size)
            )
            x += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

struct SavedValue: Identifiable, Equatable {
    let id: UUID
    let name: String
}

enum SavedValueSearch {
    static func filtered(_ values: [SavedValue], query: String) -> [SavedValue] {
        let normalizedQuery = normalized(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !normalizedQuery.isEmpty else { return values }

        return values.filter { normalized($0.name).contains(normalizedQuery) }
    }

    static func isExactMatch(_ value: String, query: String) -> Bool {
        normalized(value) == normalized(query.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func normalized(_ value: String) -> String {
        value.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
    }
}

private struct SavedValueComboBox<FocusValue: Hashable>: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let title: LocalizedStringKey
    let helper: LocalizedStringKey
    let placeholder: LocalizedStringKey
    @Binding var text: String
    let savedValues: [SavedValue]
    let menuTitle: LocalizedStringKey
    let accessibilityIdentifier: String
    let focusedField: FocusState<FocusValue?>.Binding
    let focusValue: FocusValue

    var body: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.small) {
            AssetFieldLabel(title, helper: helper)

            HStack(spacing: KaraSpacing.small) {
                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.words)
                    .focused(focusedField, equals: focusValue)
                    .accessibilityIdentifier(accessibilityIdentifier)

                Image(systemName: isFocused ? "magnifyingglass" : "chevron.up.chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.muted)
                    .accessibilityHidden(true)
            }
            .karaPurchaseInputSurface()

            if isFocused, !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Text(menuTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.muted)
                        .padding(.horizontal, 12)
                        .padding(.vertical, KaraSpacing.small)

                    ForEach(suggestions.prefix(8)) { savedValue in
                        Button {
                            select(savedValue)
                        } label: {
                            HStack(spacing: KaraSpacing.small) {
                                Image(systemName: "checkmark")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(theme.cobaltBright)
                                    .opacity(isSelected(savedValue) ? 1 : 0)
                                    .accessibilityHidden(true)

                                Text(savedValue.name)
                                    .foregroundStyle(theme.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected(savedValue) ? .isSelected : [])
                        .accessibilityIdentifier("\(accessibilityIdentifier).suggestion.\(savedValue.id)")
                    }
                }
                .padding(.bottom, KaraSpacing.xSmall)
                .background(theme.background.opacity(0.72), in: .rect(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(theme.cobaltBright.opacity(0.28), lineWidth: 1)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                .accessibilityIdentifier("\(accessibilityIdentifier).suggestions")
            }
        }
        .animation(
            KaraMotion.controlResponse(reduceMotion: reduceMotion),
            value: isFocused
        )
        .animation(
            KaraMotion.controlResponse(reduceMotion: reduceMotion),
            value: suggestions.map(\.id)
        )
    }

    private var isFocused: Bool {
        focusedField.wrappedValue == focusValue
    }

    private var suggestions: [SavedValue] {
        SavedValueSearch.filtered(savedValues, query: text)
    }

    private func isSelected(_ savedValue: SavedValue) -> Bool {
        SavedValueSearch.isExactMatch(savedValue.name, query: text)
    }

    private func select(_ savedValue: SavedValue) {
        text = savedValue.name
        focusedField.wrappedValue = nil
    }
}

private extension View {
    func karaPurchaseInputSurface() -> some View {
        self
            .font(.body)
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .background(Color.black.opacity(0.24), in: .rect(cornerRadius: 12))
    }
}
