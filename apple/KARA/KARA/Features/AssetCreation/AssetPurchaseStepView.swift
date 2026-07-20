import SwiftData
import SwiftUI

struct AssetPurchaseStepView: View {
    private enum FocusField: Hashable {
        case price
        case seller
        case storage
        case invoiceNumber
    }

    @Environment(KaraTheme.self) private var theme
    @Query(sort: \SavedSeller.lastUsedAt, order: .reverse) private var sellers: [SavedSeller]
    @Query(sort: \StorageLocation.lastUsedAt, order: .reverse) private var storageLocations: [StorageLocation]

    let state: AssetCreationState
    let onContinue: () -> Void

    @FocusState private var focusedField: FocusField?

    var body: some View {
        AssetStepScaffold(
            step: .purchase,
            navigationTitle: "purchase.navigation-title",
            title: "purchase.title",
            message: "purchase.body"
        ) {
            purchaseSection
            provenanceSection

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
    }

    private var purchaseSection: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.medium) {
            AssetSectionTitle("purchase.details.title", detail: "purchase.details.body")

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
            AssetSectionTitle("purchase.provenance.title", detail: "purchase.provenance.body")

            AssetFieldSurface {
                SavedValueField(
                    title: "details.seller",
                    helper: "purchase.seller.helper",
                    placeholder: "purchase.seller.placeholder",
                    text: binding(\.sellerName, field: .sellerName),
                    savedValues: sellers.map { SavedValue(id: $0.id, name: $0.name) },
                    menuTitle: "purchase.seller.saved",
                    accessibilityIdentifier: "details.seller"
                )
                .focused($focusedField, equals: .seller)

                Divider()

                SavedValueField(
                    title: "details.storage-location",
                    helper: "purchase.storage.helper",
                    placeholder: "purchase.storage.placeholder",
                    text: binding(\.storageLocationName, field: .storageLocationName),
                    savedValues: storageLocations.map { SavedValue(id: $0.id, name: $0.name) },
                    menuTitle: "purchase.storage.saved",
                    accessibilityIdentifier: "details.storage-location"
                )
                .focused($focusedField, equals: .storage)
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

    private func validateAndContinue() {
        guard state.validateDraft() else {
            if purchaseValidationErrors.contains(.invalidPrice) {
                focusedField = .price
            }
            return
        }
        focusedField = nil
        onContinue()
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

private struct SavedValue: Identifiable {
    let id: UUID
    let name: String
}

private struct SavedValueField: View {
    @Environment(KaraTheme.self) private var theme

    let title: LocalizedStringKey
    let helper: LocalizedStringKey
    let placeholder: LocalizedStringKey
    @Binding var text: String
    let savedValues: [SavedValue]
    let menuTitle: LocalizedStringKey
    let accessibilityIdentifier: String

    var body: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.small) {
            AssetFieldLabel(title, helper: helper)

            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.words)
                .karaPurchaseInputSurface()
                .accessibilityIdentifier(accessibilityIdentifier)

            if !savedValues.isEmpty {
                Text(menuTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.muted)

                ScrollView(.horizontal) {
                    HStack(spacing: KaraSpacing.small) {
                        ForEach(savedValues.prefix(8)) { savedValue in
                            Button(savedValue.name) {
                                text = savedValue.name
                            }
                            .buttonStyle(.glass)
                            .controlSize(.small)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .accessibilityIdentifier("\(accessibilityIdentifier).saved")
            }
        }
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
