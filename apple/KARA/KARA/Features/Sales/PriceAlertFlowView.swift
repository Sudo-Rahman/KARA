import SwiftData
import SwiftUI

@MainActor
struct PriceAlertFlowView: View {
    private enum FocusField: Hashable {
        case target
    }

    @Environment(KaraTheme.self) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let assets: [Asset]
    let attachments: [AssetAttachment]
    let valuation: PortfolioValuation

    @State private var selectedAssetID: UUID?
    @State private var targetText = ""
    @State private var validationAttempted = false
    @State private var showingDiscardConfirmation = false
    @State private var showingSaveError = false
    @State private var isSaving = false
    @State private var success: PriceAlertSuccess?
    @FocusState private var focusedField: FocusField?

    init(
        assets: [Asset],
        attachments: [AssetAttachment],
        valuation: PortfolioValuation
    ) {
        self.assets = assets
        self.attachments = attachments
        self.valuation = valuation
        let valuedIDs = Set(
            valuation.assetValuations.compactMap {
                $0.estimatedValueEUR == nil ? nil : $0.assetID
            }
        )
        _selectedAssetID = State(
            initialValue: assets.first(where: { valuedIDs.contains($0.id) })?.id
        )
    }

    var body: some View {
        Group {
            if let success {
                PriceAlertCreatedView(
                    success: success,
                    close: dismiss.callAsFunction
                )
            } else {
                form
            }
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(SalesCopy.string("alert-flow.title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            if success == nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: requestDismissal) {
                        SalesCopy.text("sales.action.cancel")
                    }
                    .accessibilityIdentifier("alert-flow.cancel")
                }
            }
        }
        .interactiveDismissDisabled(success == nil && hasEnteredData)
        .alert(
            SalesCopy.string("alert-flow.discard.title"),
            isPresented: $showingDiscardConfirmation
        ) {
            Button(
                SalesCopy.string("alert-flow.discard.action"),
                role: .destructive,
                action: dismiss.callAsFunction
            )
            Button(SalesCopy.string("sales.action.keep-editing"), role: .cancel) {}
        } message: {
            SalesCopy.text("alert-flow.discard.detail")
        }
        .alert(
            SalesCopy.string("sales.error.title"),
            isPresented: $showingSaveError
        ) {
            Button(SalesCopy.string("sales.action.ok"), role: .cancel) {}
        } message: {
            SalesCopy.text("alert-flow.error.detail")
        }
        .onChange(of: selectedAssetID) {
            targetText = ""
            validationAttempted = false
        }
    }

    private var form: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: KaraSpacing.large) {
                SalesNotice(
                    systemImage: "bell.badge.fill",
                    title: "alert-flow.intro.title",
                    detail: "alert-flow.intro.detail",
                    tint: theme.goldBright
                )

                assetSection

                if selectedAsset != nil {
                    targetSection
                }

                if validationAttempted, let validationMessageKey {
                    SalesNotice(
                        systemImage: "exclamationmark.triangle.fill",
                        title: "sales.validation.title",
                        detail: validationMessageKey,
                        tint: .orange
                    )
                    .accessibilityIdentifier("alert-flow.validation")
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
        .accessibilityIdentifier("alert-flow")
    }

    private var assetSection: some View {
        AssetFormSection(
            title: SalesCopy.text("alert-flow.asset.title"),
            detail: SalesCopy.text("alert-flow.asset.detail")
        ) {
            SalesAssetPicker(
                selectedAssetID: $selectedAssetID,
                items: assetPickerItems,
                accessibilityIdentifier: "alert-flow.asset-picker"
            )
        }
    }

    private var targetSection: some View {
        AssetFormSection(
            title: SalesCopy.text("alert-flow.target.title"),
            detail: SalesCopy.text("alert-flow.target.detail")
        ) {
            LabeledContent {
                SensitiveValue {
                    Text(
                        currentValue.map {
                            VaultFormatters.currency($0)
                        }
                            ?? "—"
                    )
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(theme.ink)
                }
            } label: {
                SalesCopy.text("alert-flow.current-value")
                    .font(.subheadline)
                    .foregroundStyle(theme.muted)
            }

            Divider()
                .overlay(theme.muted.opacity(0.18))

            AssetFieldGroup(
                title: SalesCopy.text("alert-flow.target-value")
            ) {
                HStack(alignment: .firstTextBaseline, spacing: KaraSpacing.small) {
                    TextField(
                        SalesCopy.string("alert-flow.target.placeholder"),
                        text: $targetText
                    )
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .target)
                    .assetInputSurface()
                    .accessibilityIdentifier("alert-flow.target")

                    Text(verbatim: "EUR")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(theme.muted)
                }
            }

            if let direction {
                Divider()
                    .overlay(theme.muted.opacity(0.18))

                Label(
                    SalesCopy.resource(direction.salesConditionKey),
                    systemImage: direction == .above
                        ? "arrow.up.right"
                        : "arrow.down.right"
                )
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(
                    direction == .above ? .green : theme.goldBright
                )
                .contentTransition(.numericText())
                .accessibilityIdentifier("alert-flow.direction")
            }
        }
    }

    private var submitBar: some View {
        Button(action: createAlert) {
            HStack(spacing: KaraSpacing.small) {
                if isSaving {
                    ProgressView()
                } else {
                    Image(systemName: "bell.badge.fill")
                        .accessibilityHidden(true)
                }

                SalesCopy.text(
                    isSaving
                        ? "alert-flow.action.saving"
                        : "alert-flow.action.create"
                )
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.karaPrimaryAction(isLoading: isSaving))
        .disabled(isSaving || selectedAsset == nil)
        .padding(.horizontal, KaraSpacing.large)
        .padding(.vertical, KaraSpacing.small)
        .background(theme.background)
        .accessibilityIdentifier("alert-flow.submit")
    }

    private var valuedAssets: [Asset] {
        assets.filter {
            valuationByAssetID[$0.id]?.estimatedValueEUR != nil
        }
    }

    private var valuationByAssetID: [UUID: AssetValuation] {
        Dictionary(
            uniqueKeysWithValues: valuation.assetValuations.map {
                ($0.assetID, $0)
            }
        )
    }

    private var photoDataByAssetID: [UUID: Data] {
        newestObjectPhotoDataByAssetID(attachments: attachments)
    }

    private var assetPickerItems: [SalesAssetPickerItem] {
        valuedAssets.compactMap { asset in
            guard let current =
                valuationByAssetID[asset.id]?.estimatedValueEUR
            else {
                return nil
            }
            return SalesAssetPickerItem(
                asset: asset,
                photoData: photoDataByAssetID[asset.id],
                trailingValue: VaultFormatters.currency(current),
                trailingValueIsSensitive: true
            )
        }
    }

    private var selectedAsset: Asset? {
        guard let selectedAssetID else { return nil }
        return assets.first { $0.id == selectedAssetID }
    }

    private var currentValue: Decimal? {
        selectedAssetID.flatMap {
            valuationByAssetID[$0]?.estimatedValueEUR
        }
    }

    private var targetValue: Decimal? {
        SalesAmountParser.amount(from: targetText)
    }

    private var direction: PriceAlertDirection? {
        guard let targetValue, let currentValue,
              targetValue > 0, targetValue != currentValue
        else {
            return nil
        }
        return targetValue > currentValue ? .above : .below
    }

    private var validationMessageKey: String.LocalizationValue? {
        guard let targetValue, targetValue > 0 else {
            return "alert-flow.validation.target"
        }
        guard let currentValue else {
            return "alert-flow.validation.current"
        }
        guard targetValue != currentValue else {
            return "alert-flow.validation.same"
        }
        return nil
    }

    private var hasEnteredData: Bool {
        !targetText.isEmpty
    }

    private func requestDismissal() {
        focusedField = nil
        if hasEnteredData {
            showingDiscardConfirmation = true
        } else {
            dismiss()
        }
    }

    private func createAlert() {
        validationAttempted = true
        focusedField = nil
        guard validationMessageKey == nil,
              let selectedAsset,
              let targetValue,
              let currentValue,
              let direction
        else {
            return
        }

        isSaving = true
        Task { @MainActor in
            do {
                let alert = try SalesRepository(context: modelContext).createAlert(
                    assetID: selectedAsset.id,
                    targetValue: targetValue,
                    currentValue: currentValue,
                    currencyCode: "EUR"
                )
                await PriceAlertBestEffortBackgroundRefresh.schedule()

                let notificationsAuthorized =
                    (try? await PriceAlertNotificationService()
                        .requestAuthorization()) ?? false
                success = PriceAlertSuccess(
                    alertID: alert.id,
                    assetName: selectedAsset.name,
                    targetValue: targetValue,
                    direction: direction,
                    notificationsAuthorized: notificationsAuthorized
                )
            } catch {
                showingSaveError = true
            }
            isSaving = false
        }
    }
}

private struct PriceAlertSuccess {
    let alertID: UUID
    let assetName: String
    let targetValue: Decimal
    let direction: PriceAlertDirection
    let notificationsAuthorized: Bool
}

private struct PriceAlertCreatedView: View {
    @Environment(KaraTheme.self) private var theme

    let success: PriceAlertSuccess
    let close: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: KaraSpacing.large) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 58))
                    .foregroundStyle(theme.goldBright)
                    .symbolEffect(.bounce, value: success.alertID)
                    .accessibilityHidden(true)

                VStack(spacing: KaraSpacing.small) {
                    SalesCopy.text("alert-flow.success.title")
                        .font(theme.displayFont(size: 30, relativeTo: .title))
                        .foregroundStyle(theme.ink)
                        .multilineTextAlignment(.center)

                    Text(verbatim: success.assetName)
                        .font(.headline)
                        .foregroundStyle(theme.muted)
                }

                KaraCard(padding: KaraSpacing.large) {
                    VStack(spacing: KaraSpacing.medium) {
                        SalesCopy.text(
                            success.direction == .above
                                ? "alert-flow.success.above"
                                : "alert-flow.success.below"
                        )
                        .font(.subheadline)
                        .foregroundStyle(theme.muted)

                        SensitiveValue {
                            Text(VaultFormatters.currency(success.targetValue))
                                .font(theme.displayFont(size: 34, relativeTo: .largeTitle))
                                .monospacedDigit()
                                .foregroundStyle(theme.ink)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                SalesNotice(
                    systemImage: success.notificationsAuthorized
                        ? "bell.fill"
                        : "bell.slash.fill",
                    title: success.notificationsAuthorized
                        ? "alert-flow.success.notifications.title"
                        : "alert-flow.success.notifications-off.title",
                    detail: success.notificationsAuthorized
                        ? "alert-flow.success.notifications.detail"
                        : "alert-flow.success.notifications-off.detail",
                    tint: success.notificationsAuthorized
                        ? theme.cobaltBright
                        : theme.goldBright
                )

                Button(action: close) {
                    SalesCopy.text("alert-flow.success.close")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.karaPrimaryAction)
                .accessibilityIdentifier("alert-flow.success.close")
            }
            .padding(.horizontal, KaraSpacing.large)
            .padding(.top, KaraSpacing.xxLarge)
            .padding(.bottom, KaraSpacing.xxLarge)
        }
        .accessibilityIdentifier("alert-flow.success")
    }
}
