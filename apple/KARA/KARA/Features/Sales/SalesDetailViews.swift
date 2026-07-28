import SwiftData
import SwiftUI

struct SalesHistoryView: View {
    @Environment(KaraTheme.self) private var theme

    let sales: [Sale]
    let saleLines: [SaleLine]

    var body: some View {
        ScrollView {
            if recordedSales.isEmpty {
                ContentUnavailableView {
                    Label(
                        SalesCopy.resource("sales.history.empty.title"),
                        systemImage: "receipt"
                    )
                } description: {
                    SalesCopy.text("sales.history.empty.detail")
                }
                .foregroundStyle(theme.ink)
                .frame(maxWidth: .infinity, minHeight: 420)
            } else {
                LazyVStack(alignment: .leading, spacing: KaraSpacing.large) {
                    SalesNotice(
                        systemImage: "clock.arrow.circlepath",
                        title: "sales.history.notice.title",
                        detail: "sales.history.notice.detail",
                        tint: theme.cobaltBright
                    )

                    ForEach(groupedSales, id: \.year) { group in
                        VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                            Text(group.year, format: .number.grouping(.never))
                                .font(theme.displayFont(size: 21, relativeTo: .title3))
                                .foregroundStyle(theme.ink)
                                .accessibilityAddTraits(.isHeader)

                            KaraCard {
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(
                                        Array(group.sales.enumerated()),
                                        id: \.element.id
                                    ) { index, sale in
                                        if index > 0 {
                                            Divider()
                                                .overlay(theme.muted.opacity(0.16))
                                        }

                                        NavigationLink(value: SalesRoute.sale(sale.id)) {
                                            SaleRow(
                                                sale: sale,
                                                line: line(for: sale.id)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, KaraSpacing.medium)
                .padding(.top, KaraSpacing.small)
                .padding(.bottom, KaraSpacing.xxLarge)
            }
        }
        .scrollIndicators(.hidden)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(SalesCopy.string("sales.history.title"))
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("sales.history")
    }

    private var recordedSales: [Sale] {
        sales
            .filter { $0.status == .recorded }
            .sorted { $0.soldAt > $1.soldAt }
    }

    private var groupedSales: [(year: Int, sales: [Sale])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: recordedSales) {
            calendar.component(.year, from: $0.soldAt)
        }
        return grouped.keys.sorted(by: >).map {
            ($0, grouped[$0] ?? [])
        }
    }

    private func line(for saleID: UUID) -> SaleLine? {
        saleLines.first { $0.saleID == saleID && $0.isActive }
    }
}

@MainActor
struct SaleDetailView: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let sale: Sale
    let line: SaleLine?

    @State private var showingVoidConfirmation = false
    @State private var showingError = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: KaraSpacing.large) {
                identityCard
                amountsCard
                transactionCard

                if sale.status == .recorded {
                    Button(role: .destructive) {
                        showingVoidConfirmation = true
                    } label: {
                        Label(
                            SalesCopy.resource("sale-detail.void.action"),
                            systemImage: "arrow.uturn.backward.circle"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.karaSecondaryAction)
                    .tint(.red)
                    .accessibilityIdentifier("sale-detail.void")
                }
            }
            .padding(.horizontal, KaraSpacing.medium)
            .padding(.top, KaraSpacing.small)
            .padding(.bottom, KaraSpacing.xxLarge)
        }
        .scrollIndicators(.hidden)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(SalesCopy.string("sale-detail.title"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            SalesCopy.string("sale-detail.void.confirm.title"),
            isPresented: $showingVoidConfirmation
        ) {
            Button(
                SalesCopy.string("sale-detail.void.confirm.action"),
                role: .destructive,
                action: voidSale
            )
            Button(SalesCopy.string("sales.action.cancel"), role: .cancel) {}
        } message: {
            SalesCopy.text("sale-detail.void.confirm.detail")
        }
        .alert(
            SalesCopy.string("sales.error.title"),
            isPresented: $showingError
        ) {
            Button(SalesCopy.string("sales.action.ok"), role: .cancel) {}
        } message: {
            SalesCopy.text("sale-detail.void.error")
        }
        .accessibilityIdentifier("sale-detail")
    }

    private var identityCard: some View {
        KaraCard(padding: KaraSpacing.large) {
            HStack(spacing: KaraSpacing.medium) {
                AssetArtworkView(
                    category: line?.categorySnapshot ?? .custom,
                    size: 64
                )

                VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                    Text(
                        verbatim: line?.assetNameSnapshot
                            ?? SalesCopy.string("sales.asset.unknown")
                    )
                    .font(theme.displayFont(size: 23, relativeTo: .title2))
                    .foregroundStyle(theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                    Label(
                        sale.soldAt.formatted(
                            .dateTime.day().month(.wide).year()
                        ),
                        systemImage: "calendar"
                    )
                    .font(.caption)
                    .foregroundStyle(theme.muted)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var amountsCard: some View {
        AssetFormSection(
            title: SalesCopy.text("sale-detail.amounts.title"),
            detail: SalesCopy.text("sale-detail.amounts.detail")
        ) {
            SaleDetailLine(
                title: "sale-detail.gross",
                value: VaultFormatters.currency(
                    sale.grossAmount,
                    code: sale.currencyCode,
                    maximumFractionDigits: 2
                )
            )

            saleDivider

            SaleDetailLine(
                title: "sale-detail.fees",
                value: VaultFormatters.currency(
                    sale.feesAmount,
                    code: sale.currencyCode,
                    maximumFractionDigits: 2
                )
            )

            saleDivider

            SaleDetailLine(
                title: "sale-detail.net",
                value: VaultFormatters.currency(
                    sale.netAmount,
                    code: sale.currencyCode,
                    maximumFractionDigits: 2
                ),
                emphasized: true
            )
        }
    }

    private var transactionCard: some View {
        AssetFormSection(
            title: SalesCopy.text("sale-detail.transaction.title")
        ) {
            SaleDetailLine(
                title: "sale-detail.quantity",
                value: (line?.quantity ?? 0).formatted()
            )

            if let buyer = sale.buyerName, !buyer.isEmpty {
                saleDivider
                SaleDetailLine(
                    title: "sale-detail.buyer",
                    value: buyer
                )
            }

            if let note = sale.note, !note.isEmpty {
                saleDivider
                VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                    SalesCopy.text("sale-detail.note")
                        .font(.caption)
                        .foregroundStyle(theme.muted)

                    SensitiveValue {
                        Text(verbatim: note)
                            .font(.subheadline)
                            .foregroundStyle(theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var saleDivider: some View {
        Divider()
            .overlay(theme.muted.opacity(0.18))
    }

    private func voidSale() {
        do {
            try SalesRepository(context: modelContext).voidSale(sale)
            dismiss()
        } catch {
            showingError = true
        }
    }
}

struct PriceAlertsView: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.modelContext) private var modelContext

    let alerts: [PriceAlert]
    let assets: [Asset]
    let valuation: PortfolioValuation

    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteError = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: KaraSpacing.large) {
                if alerts.isEmpty {
                    ContentUnavailableView {
                        Label(
                            SalesCopy.resource("sales.alerts.empty.title"),
                            systemImage: "bell"
                        )
                    } description: {
                        SalesCopy.text("sales.alerts.empty.detail")
                    }
                    .foregroundStyle(theme.ink)
                    .frame(maxWidth: .infinity, minHeight: 280)
                } else if !actionableAlerts.isEmpty {
                    alertSection(
                        title: "alerts.active.title",
                        alerts: actionableAlerts
                    )
                }

                if !pastAlerts.isEmpty {
                    alertSection(
                        title: "alerts.past.title",
                        alerts: pastAlerts,
                        allowsDeletingAll: true
                    )
                }
            }
            .padding(.horizontal, KaraSpacing.medium)
            .padding(.top, KaraSpacing.small)
            .padding(.bottom, KaraSpacing.xxLarge)
        }
        .scrollIndicators(.hidden)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(SalesCopy.string("alerts.title"))
        .navigationBarTitleDisplayMode(.large)
        .alert(
            SalesCopy.string("alerts.past.delete-all.confirm.title"),
            isPresented: $showingDeleteConfirmation
        ) {
            Button(
                SalesCopy.string("alerts.past.delete-all"),
                role: .destructive,
                action: deletePastAlerts
            )
            Button(SalesCopy.string("sales.action.cancel"), role: .cancel) {}
        } message: {
            SalesCopy.text("alerts.past.delete-all.confirm.detail")
        }
        .alert(
            SalesCopy.string("sales.error.title"),
            isPresented: $showingDeleteError
        ) {
            Button(SalesCopy.string("sales.action.ok"), role: .cancel) {}
        } message: {
            SalesCopy.text("alerts.past.delete-all.error")
        }
        .accessibilityIdentifier("alerts.list")
    }

    private var actionableAlerts: [PriceAlert] {
        alerts
            .filter {
                $0.status == .active
                    || $0.status == .paused
                    || $0.status == .needsReview
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var pastAlerts: [PriceAlert] {
        alerts
            .filter {
                $0.status == .triggered
                    || $0.status == .completed
                    || $0.status == .cancelled
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var valuationByAssetID: [UUID: AssetValuation] {
        Dictionary(
            uniqueKeysWithValues: valuation.assetValuations.map {
                ($0.assetID, $0)
            }
        )
    }

    private func asset(withID id: UUID) -> Asset? {
        assets.first { $0.id == id }
    }

    private func alertSection(
        title: String.LocalizationValue,
        alerts: [PriceAlert],
        allowsDeletingAll: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: KaraSpacing.medium) {
            HStack(alignment: .firstTextBaseline, spacing: KaraSpacing.small) {
                SalesCopy.text(title)
                    .font(theme.displayFont(size: 21, relativeTo: .title3))
                    .foregroundStyle(theme.ink)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: KaraSpacing.small)

                if allowsDeletingAll {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        SalesCopy.text("alerts.past.delete-all")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("alerts.past.delete-all")
                }
            }

            KaraCard {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(alerts.enumerated()), id: \.element.id) {
                        index, alert in
                        if index > 0 {
                            Divider()
                                .overlay(theme.muted.opacity(0.16))
                        }

                        NavigationLink(value: SalesRoute.alert(alert.id)) {
                            PriceAlertRow(
                                alert: alert,
                                asset: asset(withID: alert.assetID),
                                valuation: valuationByAssetID[alert.assetID]
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func deletePastAlerts() {
        do {
            try SalesRepository(context: modelContext).deletePastAlerts()
        } catch {
            showingDeleteError = true
        }
    }
}

@MainActor
struct PriceAlertDetailView: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let alert: PriceAlert
    let asset: Asset?
    let valuation: AssetValuation?

    @State private var showingCancelConfirmation = false
    @State private var showingSaveError = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: KaraSpacing.large) {
                objectiveCard

                if alert.status == .needsReview {
                    SalesNotice(
                        systemImage: "exclamationmark.arrow.triangle.2.circlepath",
                        title: "alert-detail.review.title",
                        detail: "alert-detail.review.detail",
                        tint: theme.goldBright
                    )
                } else if alert.status == .triggered {
                    SalesNotice(
                        systemImage: "checkmark.circle.fill",
                        title: "alert-detail.reached.title",
                        detail: "alert-detail.reached.detail",
                        tint: .green
                    )
                }

                statusCard

                if isActionable {
                    actions
                }
            }
            .padding(.horizontal, KaraSpacing.medium)
            .padding(.top, KaraSpacing.small)
            .padding(.bottom, KaraSpacing.xxLarge)
        }
        .scrollIndicators(.hidden)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(SalesCopy.string("alert-detail.title"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            SalesCopy.string("alert-detail.cancel.confirm.title"),
            isPresented: $showingCancelConfirmation
        ) {
            Button(
                SalesCopy.string("alert-detail.cancel.confirm.action"),
                role: .destructive,
                action: cancelAlert
            )
            Button(SalesCopy.string("sales.action.cancel"), role: .cancel) {}
        } message: {
            SalesCopy.text("alert-detail.cancel.confirm.detail")
        }
        .alert(
            SalesCopy.string("sales.error.title"),
            isPresented: $showingSaveError
        ) {
            Button(SalesCopy.string("sales.action.ok"), role: .cancel) {}
        } message: {
            SalesCopy.text("alert-detail.error")
        }
        .accessibilityIdentifier("alert-detail")
    }

    private var objectiveCard: some View {
        KaraCard(padding: KaraSpacing.large) {
            VStack(alignment: .leading, spacing: KaraSpacing.large) {
                HStack(spacing: KaraSpacing.medium) {
                    AssetArtworkView(
                        category: asset?.category ?? .custom,
                        size: 58
                    )

                    VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                        Text(
                            verbatim: asset?.name
                                ?? SalesCopy.string("sales.asset.unknown")
                        )
                        .font(.headline)
                        .foregroundStyle(theme.ink)

                        SalesCopy.text(alert.direction.salesConditionKey)
                            .font(.caption)
                            .foregroundStyle(theme.muted)
                    }
                }

                SensitiveValue {
                    Text(VaultFormatters.currency(
                        alert.targetValue,
                        code: alert.currencyCode,
                        maximumFractionDigits: 2
                    ))
                    .font(theme.displayFont(size: 36, relativeTo: .largeTitle))
                    .monospacedDigit()
                    .foregroundStyle(theme.ink)
                }

                if let current = valuation?.estimatedValueEUR {
                    HStack {
                        SalesCopy.text("alert-detail.current")
                            .font(.subheadline)
                            .foregroundStyle(theme.muted)

                        Spacer()

                        SensitiveValue {
                            Text(VaultFormatters.currency(current))
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(theme.ink)
                        }
                    }
                }
            }
        }
    }

    private var statusCard: some View {
        AssetFormSection(
            title: SalesCopy.text("alert-detail.status.title")
        ) {
            LabeledContent {
                Text(SalesCopy.resource(alert.status.salesStatusKey))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(statusColor)
            } label: {
                SalesCopy.text("alert-detail.status")
                    .font(.subheadline)
                    .foregroundStyle(theme.muted)
            }

            if let lastCheckedAt = alert.lastCheckedAt {
                Divider()
                    .overlay(theme.muted.opacity(0.18))

                LabeledContent {
                    Text(
                        lastCheckedAt,
                        format: .dateTime.day().month(.abbreviated).hour().minute()
                    )
                    .font(.subheadline)
                    .foregroundStyle(theme.ink)
                } label: {
                    SalesCopy.text("alert-detail.last-check")
                        .font(.subheadline)
                        .foregroundStyle(theme.muted)
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: KaraSpacing.small) {
            if alert.status == .active {
                Button(action: pauseAlert) {
                    Label(
                        SalesCopy.resource("alert-detail.pause"),
                        systemImage: "pause.circle.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.karaSecondaryAction)
                .accessibilityIdentifier("alert-detail.pause")
            } else if alert.status == .paused || alert.status == .needsReview {
                Button(action: resumeAlert) {
                    Label(
                        SalesCopy.resource("alert-detail.resume"),
                        systemImage: "play.circle.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.karaPrimaryAction)
                .accessibilityIdentifier("alert-detail.resume")
            }

            Button(role: .destructive) {
                showingCancelConfirmation = true
            } label: {
                Label(
                    SalesCopy.resource("alert-detail.cancel"),
                    systemImage: "xmark.circle"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.karaSecondaryAction)
            .tint(.red)
            .accessibilityIdentifier("alert-detail.cancel")
        }
    }

    private var isActionable: Bool {
        alert.status == .active
            || alert.status == .paused
            || alert.status == .needsReview
    }

    private var statusColor: Color {
        switch alert.status {
        case .active:
            theme.cobaltBright
        case .triggered:
            .green
        case .needsReview:
            theme.goldBright
        case .paused, .completed, .cancelled:
            theme.muted
        }
    }

    private func pauseAlert() {
        alert.pause()
        save()
    }

    private func resumeAlert() {
        alert.resume()
        save()
    }

    private func cancelAlert() {
        alert.cancel()
        guard save() else { return }
        dismiss()
    }

    @discardableResult
    private func save() -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            showingSaveError = true
            return false
        }
    }
}

private struct SaleDetailLine: View {
    @Environment(KaraTheme.self) private var theme

    let title: String.LocalizationValue
    let value: String
    var emphasized = false
    var isSensitive = true

    var body: some View {
        LabeledContent {
            Group {
                if isSensitive {
                    SensitiveValue {
                        valueText
                    }
                } else {
                    valueText
                }
            }
        } label: {
            SalesCopy.text(title)
                .font(emphasized ? .headline : .subheadline)
                .foregroundStyle(emphasized ? theme.ink : theme.muted)
        }
    }

    private var valueText: some View {
        Text(verbatim: value)
            .font(
                emphasized
                    ? .headline.monospacedDigit()
                    : .subheadline.monospacedDigit()
            )
            .foregroundStyle(emphasized ? theme.cobaltBright : theme.ink)
            .multilineTextAlignment(.trailing)
    }
}
