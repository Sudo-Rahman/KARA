import Foundation
import SwiftData
import SwiftUI

struct SettingsStatistics: Equatable {
    let activeAssetCount: Int
    let objectCount: Int
    let documentCount: Int
    let photoCount: Int
    let attachmentByteCount: Int64?
    let trashedAssetCount: Int

    init(
        activeAssets: [Asset],
        activeAttachments: [AssetAttachment],
        trashedAssetCount: Int,
        assetValuations: [AssetValuation] = []
    ) {
        let heldQuantities = Self.heldQuantities(
            for: activeAssets,
            assetValuations: assetValuations
        )
        activeAssetCount = heldQuantities.count
        objectCount = activeAssets.reduce(into: 0) { result, asset in
            result += heldQuantities[asset.id] ?? 0
        }

        var documents = 0
        var photos = 0
        var totalByteCount: Int64? = 0
        for attachment in activeAttachments {
            if attachment.kind == .objectPhoto {
                photos += 1
            } else {
                documents += 1
            }

            if let runningTotal = totalByteCount,
               let byteCount = attachment.dataByteCount {
                totalByteCount = runningTotal + byteCount
            } else {
                totalByteCount = nil
            }
        }

        documentCount = documents
        photoCount = photos
        attachmentByteCount = totalByteCount
        self.trashedAssetCount = trashedAssetCount
    }

    static func heldAssetIDs(
        from assets: [Asset],
        assetValuations: [AssetValuation]
    ) -> Set<UUID> {
        Set(heldQuantities(for: assets, assetValuations: assetValuations).keys)
    }

    private static func heldQuantities(
        for assets: [Asset],
        assetValuations: [AssetValuation]
    ) -> [UUID: Int] {
        var quantitiesByAssetID: [UUID: Int] = [:]
        for valuation in assetValuations where quantitiesByAssetID[valuation.assetID] == nil {
            quantitiesByAssetID[valuation.assetID] = max(0, valuation.quantity)
        }

        return assets.reduce(into: [:]) { heldQuantities, asset in
            let quantity = quantitiesByAssetID[asset.id] ?? max(0, asset.quantity)
            guard quantity > 0 else { return }
            heldQuantities[asset.id] = quantity
        }
    }

    var attachmentCount: Int {
        documentCount + photoCount
    }
}

struct AppVersionInfo: Equatable {
    let version: String
    let build: String

    init(infoDictionary: [String: Any] = Bundle.main.infoDictionary ?? [:]) {
        version = infoDictionary["CFBundleShortVersionString"] as? String ?? "—"
        build = infoDictionary["CFBundleVersion"] as? String ?? "—"
    }

    var displayName: String {
        guard build != "—" else { return version }
        return "\(version) (\(build))"
    }
}

struct SettingsView: View {
    @Environment(AppFlow.self) private var flow
    @Environment(KaraTheme.self) private var theme
    @Environment(PrivacyPreferences.self) private var privacyPreferences
    @Environment(AIFormAutofillPreferences.self) private var analysisPreferences
    @Environment(AppLockPreferences.self) private var appLockPreferences
    @Environment(AppLockController.self) private var appLockController
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Asset> { $0.deletedAt == nil }) private var activeAssets: [Asset]
    @Query(filter: #Predicate<Asset> { $0.deletedAt != nil }) private var trashedAssets: [Asset]
    @Query private var attachments: [AssetAttachment]

    private let portfolioValuation: PortfolioValuation
    private let valuationAsOf: Date
    private let versionInfo: AppVersionInfo
    @State private var appLockActivationErrorIsPresented = false

    init(
        portfolioValuation: PortfolioValuation,
        valuationAsOf: Date,
        versionInfo: AppVersionInfo = AppVersionInfo()
    ) {
        self.portfolioValuation = portfolioValuation
        self.valuationAsOf = valuationAsOf
        self.versionInfo = versionInfo
    }

    var body: some View {
        @Bindable var analysisPreferences = analysisPreferences
        @Bindable var privacyPreferences = privacyPreferences
        @Bindable var appLockPreferences = appLockPreferences
        let currentActiveAttachments = activeAttachments
        let statistics = SettingsStatistics(
            activeAssets: activeAssets,
            activeAttachments: currentActiveAttachments,
            trashedAssetCount: trashedAssets.count,
            assetValuations: portfolioValuation.assetValuations
        )
        let missingAttachmentByteCountIDs = currentActiveAttachments
            .filter { $0.dataByteCount == nil }
            .map(\.id)
            .sorted { $0.uuidString < $1.uuidString }

        Form {
            vaultSection(statistics: statistics)

            Section {
                Toggle(
                    "settings.ai.toggle",
                    isOn: $analysisPreferences.isEnabled
                )
                .tint(theme.cobaltBright)
                .accessibilityIdentifier("settings.ai.toggle")
            } header: {
                Text("settings.ai.section")
            } footer: {
                Text("settings.ai.detail")
            }
            .listRowBackground(theme.surface)

            Section {
                VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                    Toggle(
                        "settings.privacy.toggle",
                        isOn: $privacyPreferences.hidesSensitiveValues
                    )
                    .tint(theme.cobaltBright)
                    .accessibilityIdentifier("settings.privacy.toggle")

                    Text("settings.privacy.detail")
                        .font(.caption)
                        .foregroundStyle(theme.muted)
                }
                .padding(.vertical, KaraSpacing.xSmall)

                VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                    Toggle(
                        "settings.app-lock.toggle",
                        isOn: appLockEnabledBinding
                    )
                    .tint(theme.cobaltBright)
                    .disabled(appLockController.isAuthenticating)
                    .accessibilityIdentifier("settings.app-lock.toggle")

                    Text("settings.app-lock.detail")
                        .font(.caption)
                        .foregroundStyle(theme.muted)

                    if appLockPreferences.isEnabled {
                        Text("settings.app-lock.delay")
                            .font(.subheadline)
                            .foregroundStyle(theme.muted)
                            .padding(.top, KaraSpacing.small)

                        Picker(
                            "settings.app-lock.delay",
                            selection: $appLockPreferences.delay
                        ) {
                            ForEach(AppLockDelay.allCases, id: \.self) { delay in
                                Text(delay.titleKey)
                                    .tag(delay)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .accessibilityIdentifier("settings.app-lock.delay")
                    }
                }
                .padding(.vertical, KaraSpacing.xSmall)
            } header: {
                Text("settings.privacy.section")
            }
            .listRowBackground(theme.surface)

            Section {
                SettingsStatusRow(
                    title: "settings.icloud.title",
                    systemImage: "icloud.fill"
                )

                NavigationLink {
                    AssetTrashView()
                } label: {
                    SettingsNavigationRow(
                        title: "settings.trash.title",
                        detail: "settings.trash.detail",
                        systemImage: "trash",
                        count: statistics.trashedAssetCount
                    )
                }
                .accessibilityIdentifier("settings.trash")
            } header: {
                Text("settings.data.section")
            } footer: {
                Text("settings.icloud.detail")
            }
            .listRowBackground(theme.surface)

            Section {
                Button {
                    flow.replayOnboarding()
                } label: {
                    Label("settings.about.replay-onboarding", systemImage: "sparkles.rectangle.stack")
                }
                .accessibilityIdentifier("settings.replay-onboarding")

                LabeledContent("settings.about.version") {
                    Text(verbatim: versionInfo.displayName)
                        .monospacedDigit()
                        .foregroundStyle(theme.muted)
                }
            } header: {
                Text("settings.about.section")
            } footer: {
                Text("settings.about.detail")
            }
            .listRowBackground(theme.surface)
        }
        .formStyle(.grouped)
        .navigationTitle("settings.title")
        .navigationBarTitleDisplayMode(.large)
        .scrollContentBackground(.hidden)
        .background(theme.background.ignoresSafeArea())
        .foregroundStyle(theme.ink)
        .accessibilityIdentifier("settings.screen")
        .alert(
            "settings.app-lock.error.title",
            isPresented: $appLockActivationErrorIsPresented
        ) {
            Button("settings.app-lock.error.dismiss", role: .cancel) {}
        } message: {
            Text("settings.app-lock.error.detail")
        }
        .task(id: missingAttachmentByteCountIDs) {
            guard !missingAttachmentByteCountIDs.isEmpty else { return }
            let backfill = AssetAttachmentByteCountBackfill(
                modelContainer: modelContext.container
            )
            _ = try? await backfill.backfillMissingByteCounts()
        }
    }

    private var appLockEnabledBinding: Binding<Bool> {
        Binding(
            get: { appLockPreferences.isEnabled },
            set: { isEnabled in
                if isEnabled {
                    Task {
                        let result = await appLockController.requestEnable()
                        if result == .failed {
                            appLockActivationErrorIsPresented = true
                        }
                    }
                } else {
                    appLockController.disable()
                }
            }
        )
    }

    private func vaultSection(statistics: SettingsStatistics) -> some View {
        Section {
            SettingsMetricRow(
                title: "settings.vault.assets",
                systemImage: "shippingbox.fill",
                value: String(statistics.activeAssetCount),
                detail: Text("settings.vault.assets.detail \(statistics.objectCount)")
            )

            SettingsMetricRow(
                title: "settings.vault.files",
                systemImage: "doc.on.doc.fill",
                value: String(statistics.attachmentCount),
                detail: SettingsFileCountDetail(
                    documentCount: statistics.documentCount,
                    photoCount: statistics.photoCount
                )
            )

            SettingsMetricRow(
                title: "settings.vault.storage",
                systemImage: "externaldrive.fill.badge.icloud",
                value: statistics.attachmentByteCount.map {
                    Self.byteCountFormatter.string(fromByteCount: $0)
                } ?? "—",
                detail: Text("settings.vault.storage.detail")
            )

            NavigationLink {
                VaultReportPreviewView(
                    assets: activeAssets,
                    attachments: activeAttachments,
                    portfolioValuation: portfolioValuation,
                    valuationAsOf: valuationAsOf
                )
            } label: {
                SettingsReportRow(
                    isEmpty: statistics.activeAssetCount == 0
                )
            }
            .disabled(statistics.activeAssetCount == 0)
            .accessibilityIdentifier("settings.vault.report")
        } header: {
            Text("settings.vault.section")
        }
        .listRowBackground(theme.surface)
    }

    private var activeAttachments: [AssetAttachment] {
        let activeAssetIDs = SettingsStatistics.heldAssetIDs(
            from: activeAssets,
            assetValuations: portfolioValuation.assetValuations
        )
        return attachments.filter { activeAssetIDs.contains($0.assetID) }
    }

    private static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.includesCount = true
        formatter.zeroPadsFractionDigits = false
        return formatter
    }()
}

private extension AppLockDelay {
    var titleKey: LocalizedStringKey {
        switch self {
        case .immediate:
            "settings.app-lock.delay.immediate"
        case .oneMinute:
            "settings.app-lock.delay.one-minute"
        case .fiveMinutes:
            "settings.app-lock.delay.five-minutes"
        }
    }
}

private struct SettingsReportRow: View {
    @Environment(KaraTheme.self) private var theme

    let isEmpty: Bool

    var body: some View {
        HStack(spacing: KaraSpacing.medium) {
            SettingsRowIcon(systemImage: "doc.richtext.fill")

            VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                Text("settings.vault.report.title")
                    .foregroundStyle(theme.ink)
                detail
                    .font(.caption)
                    .foregroundStyle(theme.muted)
            }

            Spacer(minLength: KaraSpacing.small)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("settings.vault.report.title"))
        .accessibilityValue(accessibilityValue)
    }

    private var detail: Text {
        if isEmpty {
            Text("settings.vault.report.empty-detail")
        } else {
            Text("settings.vault.report.detail")
        }
    }

    private var accessibilityValue: Text {
        if isEmpty {
            Text("settings.vault.report.empty-detail")
        } else {
            Text("settings.vault.report.detail")
        }
    }
}

private struct SettingsFileCountDetail: View {
    let documentCount: Int
    let photoCount: Int

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                documents
                Text(verbatim: " · ")
                photos
            }

            VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                documents
                photos
            }
        }
    }

    private var documents: some View {
        Text("settings.vault.files.documents.detail \(documentCount)")
    }

    private var photos: some View {
        Text("settings.vault.files.photos.detail \(photoCount)")
    }
}

private struct SettingsMetricRow<Detail: View>: View {
    @Environment(KaraTheme.self) private var theme

    let title: LocalizedStringKey
    let systemImage: String
    let value: String
    let detail: Detail

    var body: some View {
        HStack(spacing: KaraSpacing.medium) {
            SettingsRowIcon(systemImage: systemImage)

            VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                Text(title)
                    .foregroundStyle(theme.ink)
                detail
                    .font(.caption)
                    .foregroundStyle(theme.muted)
            }

            Spacer(minLength: KaraSpacing.small)

            Text(verbatim: value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(theme.ink)
                .multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SettingsStatusRow: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        HStack(spacing: KaraSpacing.medium) {
            SettingsRowIcon(systemImage: systemImage)
            Text(title)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SettingsNavigationRow: View {
    @Environment(KaraTheme.self) private var theme

    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let systemImage: String
    let count: Int

    var body: some View {
        HStack(spacing: KaraSpacing.medium) {
            SettingsRowIcon(systemImage: systemImage)

            VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                Text(title)
                    .foregroundStyle(theme.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(theme.muted)
            }

            Spacer(minLength: KaraSpacing.small)

            if count > 0 {
                Text(verbatim: String(count))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(theme.ink)
                    .padding(.horizontal, KaraSpacing.small)
                    .padding(.vertical, KaraSpacing.xSmall)
                    .background(theme.cobalt.opacity(0.24), in: .capsule)
            }
        }
    }
}

private struct SettingsRowIcon: View {
    @Environment(KaraTheme.self) private var theme

    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(theme.goldBright)
            .frame(width: 30, height: 30)
            .background(theme.gold.opacity(0.11), in: .rect(cornerRadius: 8))
            .accessibilityHidden(true)
    }
}
