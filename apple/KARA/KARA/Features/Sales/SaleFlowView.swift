import SwiftData
import SwiftUI

@MainActor
struct SaleFlowView: View {
    private enum FocusField: Hashable {
        case grossAmount
        case fees
        case buyer
        case note
    }

    @Environment(KaraTheme.self) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let assets: [Asset]
    let attachments: [AssetAttachment]
    let valuation: PortfolioValuation
    let saleLines: [SaleLine]

    @State private var selectedAssetID: UUID?
    @State private var quantity = 1
    @State private var grossAmountText = ""
    @State private var feesText = ""
    @State private var currency: SupportedAssetCurrency = .euro
    @State private var buyerName = ""
    @State private var soldAt = Date()
    @State private var note = ""
    @State private var validationAttempted = false
    @State private var showingConfirmation = false
    @State private var showingDiscardConfirmation = false
    @State private var showingSaveError = false
    @State private var isSaving = false
    @State private var success: SaleSuccessPresentation?
    @FocusState private var focusedField: FocusField?

    init(
        assets: [Asset],
        attachments: [AssetAttachment],
        valuation: PortfolioValuation,
        saleLines: [SaleLine]
    ) {
        self.assets = assets
        self.attachments = attachments
        self.valuation = valuation
        self.saleLines = saleLines
        _selectedAssetID = State(initialValue: assets.first?.id)
    }

    var body: some View {
        Group {
            if let success {
                SaleRecordedView(success: success, close: dismiss.callAsFunction)
            } else {
                form
            }
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(SalesCopy.string("sale-flow.title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            if success == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: requestDismissal) {
                        SalesCopy.text("sales.action.cancel")
                    }
                    .accessibilityIdentifier("sale-flow.cancel")
                }
            }
        }
        .interactiveDismissDisabled(success == nil && hasEnteredData)
        .alert(
            SalesCopy.string("sale-flow.discard.title"),
            isPresented: $showingDiscardConfirmation
        ) {
            Button(
                SalesCopy.string("sale-flow.discard.action"),
                role: .destructive,
                action: dismiss.callAsFunction
            )
            Button(SalesCopy.string("sales.action.keep-editing"), role: .cancel) {}
        } message: {
            SalesCopy.text("sale-flow.discard.detail")
        }
        .alert(
            SalesCopy.string("sale-flow.confirm.title"),
            isPresented: $showingConfirmation
        ) {
            Button(
                SalesCopy.string("sale-flow.confirm.action"),
                action: recordSale
            )
            Button(SalesCopy.string("sales.action.cancel"), role: .cancel) {}
        } message: {
            Text(confirmationMessage)
        }
        .alert(
            SalesCopy.string("sales.error.title"),
            isPresented: $showingSaveError
        ) {
            Button(SalesCopy.string("sales.action.ok"), role: .cancel) {}
        } message: {
            SalesCopy.text("sale-flow.error.detail")
        }
        .onChange(of: selectedAssetID) {
            quantity = 1
            validationAttempted = false
        }
    }

    private var form: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: KaraSpacing.large) {
                SalesNotice(
                    systemImage: "checkmark.shield.fill",
                    title: "sale-flow.intro.title",
                    detail: "sale-flow.intro.detail",
                    tint: theme.cobaltBright
                )

                assetSection

                if let selectedAsset {
                    amountSection(for: selectedAsset)
                    buyerSection
                    summarySection
                }

                if validationAttempted, let validationError {
                    SalesNotice(
                        systemImage: "exclamationmark.triangle.fill",
                        title: "sales.validation.title",
                        detail: validationError.salesMessageKey,
                        tint: .orange
                    )
                    .accessibilityIdentifier("sale-flow.validation")
                }
            }
            .padding(.horizontal, KaraSpacing.large)
            .padding(.top, KaraSpacing.medium)
            .padding(.bottom, KaraSpacing.xxLarge)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            submitBar
        }
        .accessibilityIdentifier("sale-flow")
    }

    private var assetSection: some View {
        AssetFormSection(
            title: SalesCopy.text("sale-flow.asset.title"),
            detail: SalesCopy.text("sale-flow.asset.detail")
        ) {
            SalesAssetPicker(
                selectedAssetID: $selectedAssetID,
                items: assetPickerItems,
                accessibilityIdentifier: "sale-flow.asset-picker"
            )
        }
    }

    private func amountSection(for asset: Asset) -> some View {
        AssetFormSection(
            title: SalesCopy.text("sale-flow.amount.title"),
            detail: SalesCopy.text("sale-flow.amount.detail")
        ) {
            if heldQuantity(for: asset) > 1 {
                Stepper(
                    value: $quantity,
                    in: 1 ... heldQuantity(for: asset)
                ) {
                    LabeledContent(SalesCopy.string("sale-flow.quantity")) {
                        Text(quantity, format: .number)
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(theme.ink)
                            .contentTransition(.numericText())
                    }
                }
                .accessibilityIdentifier("sale-flow.quantity")

                salesDivider
            }

            SalesFormField(
                title: "sale-flow.gross.title",
                helper: "sale-flow.gross.detail"
            ) {
                HStack(alignment: .firstTextBaseline, spacing: KaraSpacing.small) {
                    TextField(
                        SalesCopy.string("sale-flow.gross.placeholder"),
                        text: $grossAmountText
                    )
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .grossAmount)
                    .assetInputSurface()
                    .accessibilityIdentifier("sale-flow.gross")

                    Picker(
                        SalesCopy.string("sale-flow.currency"),
                        selection: $currency
                    ) {
                        ForEach(SupportedAssetCurrency.allCases) { currency in
                            Text(verbatim: currency.rawValue).tag(currency)
                        }
                    }
                    .pickerStyle(.menu)
                    .assetPickerSurface()
                    .accessibilityIdentifier("sale-flow.currency")
                }
            }

            if let estimate = estimatedValueForSelectedQuantity {
                Button {
                    grossAmountText = decimalInputString(estimate)
                } label: {
                    Label(
                        SalesCopy.resource("sale-flow.use-estimate"),
                        systemImage: "wand.and.stars"
                    )
                    .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.cobaltBright)
                .accessibilityValue(VaultFormatters.currency(estimate))
            }

            salesDivider

            SalesFormField(
                title: "sale-flow.fees.title",
                helper: "sale-flow.fees.detail"
            ) {
                TextField(
                    SalesCopy.string("sale-flow.fees.placeholder"),
                    text: $feesText
                )
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .fees)
                .assetInputSurface()
                .accessibilityIdentifier("sale-flow.fees")
            }
        }
    }

    private var buyerSection: some View {
        AssetFormSection(
            title: SalesCopy.text("sale-flow.details.title"),
            detail: SalesCopy.text("sale-flow.details.detail")
        ) {
            DatePicker(
                SalesCopy.string("sale-flow.date"),
                selection: $soldAt,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .accessibilityIdentifier("sale-flow.date")

            salesDivider

            SalesFormField(
                title: "sale-flow.buyer.title",
                helper: "sale-flow.optional"
            ) {
                TextField(
                    SalesCopy.string("sale-flow.buyer.placeholder"),
                    text: $buyerName
                )
                .textInputAutocapitalization(.words)
                .focused($focusedField, equals: .buyer)
                .assetInputSurface()
                .accessibilityIdentifier("sale-flow.buyer")
            }

            salesDivider

            SalesFormField(
                title: "sale-flow.note.title",
                helper: "sale-flow.optional"
            ) {
                TextField(
                    SalesCopy.string("sale-flow.note.placeholder"),
                    text: $note,
                    axis: .vertical
                )
                .lineLimit(2 ... 5)
                .focused($focusedField, equals: .note)
                .assetInputSurface()
                .accessibilityIdentifier("sale-flow.note")
            }
        }
    }

    private var summarySection: some View {
        AssetFormSection(
            title: SalesCopy.text("sale-flow.summary.title"),
            detail: SalesCopy.text("sale-flow.summary.detail")
        ) {
            SalesSummaryLine(
                title: "sale-flow.summary.gross",
                amount: grossAmount,
                currencyCode: currency.rawValue
            )
            salesDivider
            SalesSummaryLine(
                title: "sale-flow.summary.fees",
                amount: feesAmount,
                currencyCode: currency.rawValue
            )
            salesDivider
            SalesSummaryLine(
                title: "sale-flow.summary.net",
                amount: netAmount,
                currencyCode: currency.rawValue,
                emphasized: true
            )
        }
    }

    private var submitBar: some View {
        Button(action: validateAndConfirm) {
            HStack(spacing: KaraSpacing.small) {
                if isSaving {
                    ProgressView()
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .accessibilityHidden(true)
                }

                SalesCopy.text(
                    isSaving
                        ? "sale-flow.action.saving"
                        : "sale-flow.action.continue"
                )
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.karaPrimaryAction(isLoading: isSaving))
        .disabled(isSaving || selectedAsset == nil)
        .padding(.horizontal, KaraSpacing.large)
        .padding(.vertical, KaraSpacing.small)
        .background(theme.background)
        .accessibilityIdentifier("sale-flow.submit")
    }

    private var salesDivider: some View {
        Divider()
            .overlay(theme.muted.opacity(0.18))
    }

    private var selectedAsset: Asset? {
        guard let selectedAssetID else { return nil }
        return assets.first { $0.id == selectedAssetID }
    }

    private var valuationByAssetID: [UUID: AssetValuation] {
        Dictionary(
            uniqueKeysWithValues: valuation.assetValuations.map {
                ($0.assetID, $0)
            }
        )
    }

    private var selectedAssetValuation: AssetValuation? {
        selectedAssetID.flatMap { valuationByAssetID[$0] }
    }

    private var photoDataByAssetID: [UUID: Data] {
        newestObjectPhotoDataByAssetID(attachments: attachments)
    }

    private var assetPickerItems: [SalesAssetPickerItem] {
        assets.map { asset in
            let heldQuantity = heldQuantity(for: asset)
            return SalesAssetPickerItem(
                asset: asset,
                photoData: photoDataByAssetID[asset.id],
                trailingValue: heldQuantity > 1
                    ? SalesCopy.formatted(
                        "sale-flow.asset.held-count",
                        heldQuantity
                    )
                    : nil,
                trailingValueIsSensitive: false
            )
        }
    }

    private var grossAmount: Decimal? {
        SalesAmountParser.amount(from: grossAmountText)
    }

    private var feesAmount: Decimal? {
        let trimmed = feesText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? 0 : SalesAmountParser.amount(from: trimmed)
    }

    private var netAmount: Decimal? {
        guard let grossAmount, let feesAmount else { return nil }
        return grossAmount - feesAmount
    }

    private var validationError: SalesFormValidationError? {
        guard let selectedAsset else { return .invalidQuantity }
        return SalesFormValidator.validate(
            grossAmount: grossAmount,
            feesAmount: feesAmount,
            quantity: quantity,
            heldQuantity: heldQuantity(for: selectedAsset),
            soldAt: soldAt,
            purchaseDate: selectedAsset.purchaseDate
        )
    }

    private var estimatedValueForSelectedQuantity: Decimal? {
        guard currency == .euro,
              let selectedAssetValuation,
              let totalValue = selectedAssetValuation.estimatedValueEUR,
              selectedAssetValuation.quantity > 0
        else {
            return nil
        }

        return totalValue
            * Decimal(quantity)
            / Decimal(selectedAssetValuation.quantity)
    }

    private var hasEnteredData: Bool {
        !grossAmountText.isEmpty
            || !feesText.isEmpty
            || !buyerName.isEmpty
            || !note.isEmpty
            || quantity != 1
    }

    private var confirmationMessage: String {
        guard let selectedAsset, let netAmount else {
            return SalesCopy.string("sale-flow.confirm.fallback")
        }
        return SalesCopy.formatted(
            "sale-flow.confirm.detail",
            quantity,
            selectedAsset.name,
            VaultFormatters.currency(
                netAmount,
                code: currency.rawValue,
                maximumFractionDigits: 2
            )
        )
    }

    private func heldQuantity(for asset: Asset) -> Int {
        SalesLedger.heldQuantity(
            for: asset,
            recordedSaleLines: saleLines
        )
    }

    private func decimalInputString(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: amount as NSDecimalNumber)
            ?? "\(amount)"
    }

    private func validateAndConfirm() {
        validationAttempted = true
        focusedField = nil
        guard validationError == nil else { return }
        showingConfirmation = true
    }

    private func requestDismissal() {
        focusedField = nil
        if hasEnteredData {
            showingDiscardConfirmation = true
        } else {
            dismiss()
        }
    }

    private func recordSale() {
        guard let selectedAsset,
              let grossAmount,
              let feesAmount
        else {
            validationAttempted = true
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let spotValue: Decimal? =
                Calendar.current.isDateInToday(soldAt)
                    && currency == .euro
                    ? estimatedValueForSelectedQuantity
                    : nil
            let result = try SalesRepository(context: modelContext).recordSale(
                asset: selectedAsset,
                quantity: quantity,
                grossAmount: grossAmount,
                feesAmount: feesAmount,
                currencyCode: currency.rawValue,
                soldAt: soldAt,
                buyerName: buyerName.nilIfBlank,
                note: note.nilIfBlank,
                spotValueAtSale: spotValue
            )
            success = SaleSuccessPresentation(
                saleID: result.sale.id,
                assetName: selectedAsset.name,
                netAmount: result.sale.netAmount,
                currencyCode: result.sale.currencyCode,
                disposition: result.disposition
            )
        } catch {
            showingSaveError = true
        }
    }
}

private struct SalesFormField<Content: View>: View {
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
        AssetFieldGroup(
            title: SalesCopy.text(title),
            helper: helper.map { SalesCopy.text($0) }
        ) {
            content
        }
    }
}

private struct SalesSummaryLine: View {
    @Environment(KaraTheme.self) private var theme

    let title: String.LocalizationValue
    let amount: Decimal?
    let currencyCode: String
    var emphasized = false

    var body: some View {
        LabeledContent {
            SensitiveValue {
                Text(
                    amount.map {
                        VaultFormatters.currency(
                            $0,
                            code: currencyCode,
                            maximumFractionDigits: 2
                        )
                    } ?? "—"
                )
                .font(
                    emphasized
                        ? .headline.monospacedDigit()
                        : .subheadline.monospacedDigit()
                )
                .foregroundStyle(emphasized ? theme.cobaltBright : theme.ink)
            }
        } label: {
            SalesCopy.text(title)
                .font(emphasized ? .headline : .subheadline)
                .foregroundStyle(emphasized ? theme.ink : theme.muted)
        }
    }
}

private struct SaleRecordedView: View {
    @Environment(KaraTheme.self) private var theme

    let success: SaleSuccessPresentation
    let close: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: KaraSpacing.large) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: success.saleID)
                    .accessibilityHidden(true)

                VStack(spacing: KaraSpacing.small) {
                    SalesCopy.text("sale-flow.success.title")
                        .font(theme.displayFont(size: 30, relativeTo: .title))
                        .foregroundStyle(theme.ink)
                        .multilineTextAlignment(.center)

                    Text(verbatim: success.assetName)
                        .font(.headline)
                        .foregroundStyle(theme.muted)
                        .multilineTextAlignment(.center)
                }

                KaraCard(padding: KaraSpacing.large) {
                    VStack(spacing: KaraSpacing.medium) {
                        SalesCopy.text("sale-flow.success.received")
                            .font(.subheadline)
                            .foregroundStyle(theme.muted)

                        SensitiveValue {
                            Text(VaultFormatters.currency(
                                success.netAmount,
                                code: success.currencyCode,
                                maximumFractionDigits: 2
                            ))
                            .font(theme.displayFont(size: 34, relativeTo: .largeTitle))
                            .monospacedDigit()
                            .foregroundStyle(theme.ink)
                        }

                        Divider()
                            .overlay(theme.muted.opacity(0.18))

                        Label(
                            SalesCopy.resource(
                                success.disposition == .full
                                    ? "sale-flow.success.full"
                                    : "sale-flow.success.partial"
                            ),
                            systemImage: success.disposition == .full
                                ? "archivebox.fill"
                                : "shippingbox.fill"
                        )
                        .font(.subheadline)
                        .foregroundStyle(theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity)
                }

                Button(action: close) {
                    SalesCopy.text("sale-flow.success.close")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.karaPrimaryAction)
                .accessibilityIdentifier("sale-flow.success.close")
            }
            .padding(.horizontal, KaraSpacing.large)
            .padding(.top, KaraSpacing.xxLarge)
            .padding(.bottom, KaraSpacing.xxLarge)
        }
        .accessibilityIdentifier("sale-flow.success")
    }
}

private extension SalesFormValidationError {
    var salesMessageKey: String.LocalizationValue {
        switch self {
        case .invalidGrossAmount:
            "sales.validation.gross"
        case .invalidFees:
            "sales.validation.fees"
        case .feesExceedGrossAmount:
            "sales.validation.fees-above-gross"
        case .invalidQuantity:
            "sales.validation.quantity"
        case .quantityExceedsHolding:
            "sales.validation.quantity-exceeds"
        case .salePredatesPurchase:
            "sales.validation.sale-predates-purchase"
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
