import SwiftUI

enum SalesRoute: Hashable {
    case history
    case sale(UUID)
    case alerts
    case alert(UUID)
}

private enum SalesSheetDestination: String, Identifiable {
    case newSale
    case newAlert

    var id: String { rawValue }
}

struct SalesDashboardView: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let assets: [Asset]
    let assetCatalog: [Asset]
    let attachments: [AssetAttachment]
    let valuation: PortfolioValuation
    let sales: [Sale]
    let saleLines: [SaleLine]
    let alerts: [PriceAlert]
    let isRefreshing: Bool
    let refresh: @MainActor () async -> Void

    @State private var sheet: SalesSheetDestination?
    @State private var isRequestingRefresh = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: KaraSpacing.large) {
                introduction
                primaryActions

                if assets.isEmpty {
                    noHeldAssetsNotice
                } else if valuedAssets.isEmpty {
                    valuationUnavailableCard
                }

                alertsSection
                recentSalesSection
            }
            .padding(.horizontal, KaraSpacing.medium)
            .padding(.top, KaraSpacing.small)
            .padding(.bottom, KaraSpacing.xxLarge)
        }
        .scrollIndicators(.hidden)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(SalesCopy.resource("sales.title"))
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: SalesRoute.self) { route in
            destination(for: route)
        }
        .sheet(item: $sheet) { destination in
            NavigationStack {
                switch destination {
                case .newSale:
                    SaleFlowView(
                        assets: assets,
                        attachments: attachments,
                        valuation: valuation,
                        saleLines: saleLines
                    )
                case .newAlert:
                    PriceAlertFlowView(
                        assets: assets,
                        attachments: attachments,
                        valuation: valuation
                    )
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .accessibilityIdentifier("sales.dashboard")
    }

    private var introduction: some View {
        Text(SalesCopy.resource("sales.subtitle"))
            .font(.subheadline)
            .foregroundStyle(theme.muted)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var primaryActions: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: KaraSpacing.small) {
                saleAction
                alertAction
            }
        } else {
            HStack(alignment: .top, spacing: KaraSpacing.small) {
                saleAction
                alertAction
            }
        }
    }

    private var saleAction: some View {
        Button {
            sheet = .newSale
        } label: {
            SalesQuickAction(
                title: "sales.action.record",
                detail: "sales.action.record.detail",
                systemImage: "banknote.fill",
                isPrimary: true
            )
        }
        .buttonStyle(.plain)
        .disabled(assets.isEmpty)
        .accessibilityIdentifier("sales.record")
    }

    private var alertAction: some View {
        Button {
            sheet = .newAlert
        } label: {
            SalesQuickAction(
                title: "sales.action.objective",
                detail: "sales.action.objective.detail",
                systemImage: "bell.badge.fill",
                isPrimary: false
            )
        }
        .buttonStyle(.plain)
        .disabled(valuedAssets.isEmpty)
        .accessibilityHint(
            valuedAssets.isEmpty
                ? SalesCopy.text("sales.valuation.unavailable.detail")
                : Text("")
        )
        .accessibilityIdentifier("sales.alert.create")
    }

    private var noHeldAssetsNotice: some View {
        SalesNotice(
            systemImage: "shippingbox",
            title: "sales.no-assets.title",
            detail: "sales.no-assets.detail",
            tint: theme.goldBright
        )
    }

    private var valuationUnavailableCard: some View {
        SalesEmptyCard(
            systemImage: valuationRefreshInProgress
                ? "arrow.clockwise"
                : "chart.line.downtrend.xyaxis",
            title: valuationRefreshInProgress
                ? "sales.valuation.loading.title"
                : "sales.valuation.unavailable.title",
            detail: valuationRefreshInProgress
                ? "sales.valuation.loading.detail"
                : "sales.valuation.unavailable.detail"
        ) {
            if valuationRefreshInProgress {
                HStack(spacing: KaraSpacing.small) {
                    ProgressView()
                    SalesCopy.text("sales.valuation.loading.action")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.muted)
                .accessibilityElement(children: .combine)
            } else {
                Button(action: requestValuationRefresh) {
                    Label(
                        SalesCopy.resource("sales.valuation.refresh"),
                        systemImage: "arrow.clockwise"
                    )
                }
                .buttonStyle(.karaSecondaryAction)
                .accessibilityIdentifier("sales.valuation.refresh")
            }
        }
    }

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.medium) {
            sectionHeader(
                title: "sales.alerts.title",
                action: alerts.isEmpty ? nil : "sales.action.see-all",
                route: alerts.isEmpty ? nil : .alerts
            )

            if alerts.isEmpty {
                SalesEmptyCard(
                    systemImage: "bell",
                    title: "sales.alerts.empty.title",
                    detail: "sales.alerts.empty.detail"
                ) {
                    if !valuedAssets.isEmpty {
                        Button {
                            sheet = .newAlert
                        } label: {
                            SalesCopy.text("sales.action.objective")
                        }
                        .buttonStyle(.karaSecondaryAction)
                    }
                }
            } else {
                KaraCard {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(
                            Array(dashboardAlerts.prefix(3).enumerated()),
                            id: \.element.id
                        ) { index, alert in
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
    }

    private var recentSalesSection: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.medium) {
            sectionHeader(
                title: "sales.recent.title",
                action: recordedSales.isEmpty ? nil : "sales.history.action",
                route: recordedSales.isEmpty ? nil : .history
            )

            if recordedSales.isEmpty {
                SalesEmptyCard(
                    systemImage: "receipt",
                    title: "sales.empty.title",
                    detail: "sales.empty.detail"
                ) {
                    if !assets.isEmpty {
                        Button {
                            sheet = .newSale
                        } label: {
                            SalesCopy.text("sales.action.record")
                        }
                        .buttonStyle(.karaPrimaryAction)
                    }
                }
            } else {
                KaraCard {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(
                            Array(recordedSales.prefix(5).enumerated()),
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

    private func sectionHeader(
        title: String.LocalizationValue,
        action: String.LocalizationValue?,
        route: SalesRoute?
    ) -> some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: KaraSpacing.small) {
                    sectionTitle(title)

                    if let action, let route {
                        sectionAction(action, route: route)
                    }
                }
            } else {
                HStack(alignment: .lastTextBaseline, spacing: KaraSpacing.medium) {
                    sectionTitle(title)

                    Spacer()

                    if let action, let route {
                        sectionAction(action, route: route)
                    }
                }
            }
        }
    }

    private func sectionTitle(
        _ title: String.LocalizationValue
    ) -> some View {
        SalesCopy.text(title)
            .font(theme.displayFont(size: 21, relativeTo: .title3))
            .foregroundStyle(theme.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func sectionAction(
        _ action: String.LocalizationValue,
        route: SalesRoute
    ) -> some View {
        NavigationLink(value: route) {
            SalesCopy.text(action)
                .font(.caption.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func destination(for route: SalesRoute) -> some View {
        switch route {
        case .history:
            SalesHistoryView(sales: sales, saleLines: saleLines)
        case let .sale(id):
            if let sale = sales.first(where: { $0.id == id }) {
                SaleDetailView(
                    sale: sale,
                    line: line(for: id)
                )
            } else {
                SalesMissingContentView()
            }
        case .alerts:
            PriceAlertsView(
                alerts: alerts,
                assets: assetCatalog,
                valuation: valuation
            )
        case let .alert(id):
            if let alert = alerts.first(where: { $0.id == id }) {
                PriceAlertDetailView(
                    alert: alert,
                    asset: asset(withID: alert.assetID),
                    valuation: valuationByAssetID[alert.assetID]
                )
            } else {
                SalesMissingContentView()
            }
        }
    }

    private var recordedSales: [Sale] {
        sales
            .filter { $0.status == .recorded }
            .sorted { $0.soldAt > $1.soldAt }
    }

    private var dashboardAlerts: [PriceAlert] {
        alerts
            .sorted { lhs, rhs in
                if lhs.status.dashboardPriority == rhs.status.dashboardPriority {
                    return lhs.updatedAt > rhs.updatedAt
                }
                return lhs.status.dashboardPriority < rhs.status.dashboardPriority
            }
    }

    private var valuationByAssetID: [UUID: AssetValuation] {
        Dictionary(
            uniqueKeysWithValues: valuation.assetValuations.map {
                ($0.assetID, $0)
            }
        )
    }

    private var valuedAssets: [Asset] {
        assets.filter {
            valuationByAssetID[$0.id]?.estimatedValueEUR != nil
        }
    }

    private var valuationRefreshInProgress: Bool {
        isRefreshing || isRequestingRefresh
    }

    private func requestValuationRefresh() {
        guard !valuationRefreshInProgress else { return }
        isRequestingRefresh = true
        Task { @MainActor in
            await refresh()
            isRequestingRefresh = false
        }
    }

    private func asset(withID id: UUID) -> Asset? {
        assetCatalog.first { $0.id == id }
    }

    private func line(for saleID: UUID) -> SaleLine? {
        saleLines.first { $0.saleID == saleID }
    }
}

private extension PriceAlertStatus {
    var dashboardPriority: Int {
        switch self {
        case .triggered:
            0
        case .needsReview:
            1
        case .active:
            2
        case .paused:
            3
        case .completed:
            4
        case .cancelled:
            5
        }
    }
}

private struct SalesQuickAction: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.isEnabled) private var isEnabled

    let title: String.LocalizationValue
    let detail: String.LocalizationValue
    let systemImage: String
    let isPrimary: Bool

    var body: some View {
        KaraCard(padding: KaraSpacing.medium, minHeight: 142) {
            VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isPrimary ? theme.ink : theme.goldBright)
                    .frame(width: 42, height: 42)
                    .background(
                        (isPrimary ? theme.cobalt : theme.gold).opacity(0.18),
                        in: .circle
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                    SalesCopy.text(title)
                        .font(.headline)
                        .foregroundStyle(theme.ink)

                    SalesCopy.text(detail)
                        .font(.caption)
                        .foregroundStyle(theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .opacity(isEnabled ? 1 : 0.48)
    }
}

struct SalesEmptyCard<Actions: View>: View {
    @Environment(KaraTheme.self) private var theme

    let systemImage: String
    let title: String.LocalizationValue
    let detail: String.LocalizationValue
    @ViewBuilder let actions: Actions

    init(
        systemImage: String,
        title: String.LocalizationValue,
        detail: String.LocalizationValue,
        @ViewBuilder actions: () -> Actions
    ) {
        self.systemImage = systemImage
        self.title = title
        self.detail = detail
        self.actions = actions()
    }

    var body: some View {
        KaraCard(padding: KaraSpacing.large) {
            VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(theme.goldBright)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                    SalesCopy.text(title)
                        .font(.headline)
                        .foregroundStyle(theme.ink)

                    SalesCopy.text(detail)
                        .font(.subheadline)
                        .foregroundStyle(theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                actions
            }
        }
    }
}

struct SaleRow: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let sale: Sale
    let line: SaleLine?

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                    HStack(alignment: .top, spacing: KaraSpacing.medium) {
                        artwork
                        identity
                        Spacer(minLength: KaraSpacing.small)
                        chevron
                    }

                    amount(alignment: .leading)
                }
            } else {
                HStack(spacing: KaraSpacing.medium) {
                    artwork
                    identity
                    Spacer(minLength: KaraSpacing.small)
                    amount(alignment: .trailing)
                    chevron
                }
            }
        }
        .padding(.vertical, KaraSpacing.small)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var artwork: some View {
        AssetArtworkView(
            category: line?.categorySnapshot ?? .custom,
            size: 50
        )
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
            Text(verbatim: line?.assetNameSnapshot ?? SalesCopy.string(
                "sales.asset.unknown"
            ))
            .font(.headline)
            .foregroundStyle(theme.ink)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)

            HStack(spacing: 5) {
                Text(sale.soldAt, format: .dateTime.day().month(.abbreviated).year())
                if let buyer = sale.buyerName, !buyer.isEmpty {
                    Text("·")
                    SensitiveValue {
                        Text(verbatim: buyer)
                    }
                }
            }
            .font(.caption)
            .foregroundStyle(theme.muted)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
        }
    }

    private func amount(
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: KaraSpacing.xSmall) {
            SensitiveValue {
                Text(VaultFormatters.currency(
                    sale.netAmount,
                    code: sale.currencyCode,
                    maximumFractionDigits: 2
                ))
                .font(.headline.monospacedDigit())
                .foregroundStyle(theme.ink)
            }

            SalesCopy.text("sales.amount.received")
                .font(.caption2)
                .foregroundStyle(theme.muted)
        }
        .frame(
            maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil,
            alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing
        )
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(theme.muted)
            .accessibilityHidden(true)
    }
}

struct PriceAlertRow: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let alert: PriceAlert
    let asset: Asset?
    let valuation: AssetValuation?

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                    HStack(alignment: .top, spacing: KaraSpacing.medium) {
                        artwork
                        identity
                        Spacer(minLength: KaraSpacing.small)
                        chevron
                    }

                    objective(alignment: .leading)
                }
            } else {
                HStack(spacing: KaraSpacing.medium) {
                    artwork
                    identity
                    Spacer(minLength: KaraSpacing.small)
                    objective(alignment: .trailing)
                    chevron
                }
            }
        }
        .padding(.vertical, KaraSpacing.small)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var artwork: some View {
        AssetArtworkView(
            category: asset?.category ?? .custom,
            size: 50
        )
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
            Text(verbatim: asset?.name ?? SalesCopy.string("sales.asset.unknown"))
                .font(.headline)
                .foregroundStyle(theme.ink)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)

            if let current = valuation?.estimatedValueEUR {
                SensitiveValue {
                    Text(VaultFormatters.currency(current))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(theme.muted)
                }
            }
        }
    }

    private func objective(
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: KaraSpacing.xSmall) {
            SensitiveValue {
                Text(VaultFormatters.currency(
                    alert.targetValue,
                    code: alert.currencyCode,
                    maximumFractionDigits: 2
                ))
                .font(.headline.monospacedDigit())
                .foregroundStyle(theme.ink)
            }

            Text(SalesCopy.resource(alert.status.salesStatusKey))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(alertStatusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(alertStatusColor.opacity(0.12), in: .capsule)
        }
        .frame(
            maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil,
            alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing
        )
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.semibold))
            .foregroundStyle(theme.muted)
            .accessibilityHidden(true)
    }

    private var alertStatusColor: Color {
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
}

struct SalesNotice: View {
    @Environment(KaraTheme.self) private var theme

    let systemImage: String
    let title: String.LocalizationValue
    let detail: String.LocalizationValue
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: KaraSpacing.medium) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.12), in: .circle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                SalesCopy.text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.ink)

                SalesCopy.text(detail)
                    .font(.caption)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(KaraSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08), in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(tint.opacity(0.20), lineWidth: 1)
        }
    }
}

struct SalesMissingContentView: View {
    @Environment(KaraTheme.self) private var theme

    var body: some View {
        ContentUnavailableView {
            Label(
                SalesCopy.resource("sales.missing.title"),
                systemImage: "questionmark.folder"
            )
        } description: {
            SalesCopy.text("sales.missing.detail")
        }
        .foregroundStyle(theme.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background.ignoresSafeArea())
    }
}
