import SwiftUI
import UIKit

struct AssetDetailView: View {
    @Environment(AppRouter.self) private var router
    @Environment(KaraTheme.self) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let asset: Asset
    let attachments: [AssetAttachment]
    let valuation: AssetValuation?
    let repository: any AssetTrashManaging

    @State private var deletionRequest: AssetDeletionRequest?
    @State private var isShowingDeletionConfirmation = false
    @State private var isShowingDeletionError = false

    var body: some View {
        let renderData = AssetDetailRenderData(
            assetID: asset.id,
            attachments: attachments
        )

        ScrollView {
            LazyVStack(alignment: .leading, spacing: KaraSpacing.large) {
                hero(photoData: renderData.objectPhotoData)
                valueCard
                completenessCard
                compositionCard
                acquisitionCard

                if !asset.tags.isEmpty {
                    tagsSection
                }

                documentsCard(attachments: renderData.attachments)
            }
            .padding(.horizontal, KaraSpacing.medium)
            .padding(.top, KaraSpacing.small)
            .padding(.bottom, KaraSpacing.xxLarge)
        }
        .scrollIndicators(.hidden)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(asset.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button {
                        router.presentEditor(for: asset.id)
                    } label: {
                        Label("asset-detail.action.edit", systemImage: "pencil")
                    }
                    .accessibilityIdentifier("asset-detail.edit")

                    Divider()

                    Button(role: .destructive) {
                        requestDeletion()
                    } label: {
                        Label("asset-delete.action.delete", systemImage: "trash")
                    }
                    .accessibilityIdentifier("asset-detail.delete")
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel(Text("asset-detail.action.more"))
                .accessibilityIdentifier("asset-detail.more")
            }
        }
        .assetDeletionPresentation(
            request: $deletionRequest,
            isPresentingConfirmation: $isShowingDeletionConfirmation,
            isShowingError: $isShowingDeletionError,
            delete: repository.moveToTrash,
            onDeleted: router.dismissCurrentRoute
        )
        .accessibilityIdentifier("asset-detail.screen")
    }

    private func hero(photoData: Data?) -> some View {
        ZStack(alignment: .bottomLeading) {
            AssetDetailHeroImage(
                category: asset.category,
                photoData: photoData
            )
            .frame(maxWidth: .infinity)
            .frame(height: 230)

            LinearGradient(
                colors: [.clear, theme.background.opacity(0.88)],
                startPoint: .center,
                endPoint: .bottom
            )
            .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: KaraSpacing.small) {
                HStack(spacing: KaraSpacing.small) {
                    VaultStatusPill(
                        text: LocalizedStringKey(asset.category.localizationKey),
                        systemImage: asset.category.symbolName,
                        tint: theme.goldBright
                    )

                    if asset.quantity > 1 {
                        SensitiveValue {
                            Text("asset-detail.quantity \(asset.quantity)")
                                .font(.caption.weight(.semibold).monospacedDigit())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(theme.surface.opacity(0.78), in: .capsule)
                        }
                    }
                }

                Text(asset.name)
                    .font(theme.displayFont(size: 28, relativeTo: .title))
                    .foregroundStyle(theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if let metal = asset.metal {
                    Text(metal.localizedKey)
                        .font(.subheadline)
                        .foregroundStyle(theme.muted)
                }
            }
            .padding(KaraSpacing.large)
        }
        .clipShape(.rect(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }

    private var valueCard: some View {
        KaraCard(padding: KaraSpacing.large) {
            VStack(alignment: .leading, spacing: KaraSpacing.large) {
                VaultSectionHeader("asset-detail.value.title", eyebrow: "asset-detail.value.eyebrow") {
                    if valuation?.status == .valued {
                        VaultStatusPill(
                            text: "asset-detail.value.spot",
                            systemImage: "dot.radiowaves.left.and.right",
                            tint: .green
                        )
                    }
                }

                if let value = valuation?.estimatedValueEUR {
                    SensitiveValue {
                        Text(VaultFormatters.currency(value))
                            .font(theme.displayFont(size: 36, relativeTo: .largeTitle))
                            .monospacedDigit()
                            .foregroundStyle(theme.ink)
                            .contentTransition(.numericText())
                    }
                } else {
                    VStack(alignment: .leading, spacing: KaraSpacing.small) {
                        Text("asset-detail.value.unavailable")
                            .font(theme.displayFont(size: 25, relativeTo: .title2))
                            .foregroundStyle(theme.ink)

                        Text(valuationStatusKey)
                            .font(.caption)
                            .foregroundStyle(theme.muted)
                    }
                }

                Divider()
                    .overlay(theme.muted.opacity(0.16))

                valueMetrics
            }
        }
    }

    @ViewBuilder
    private var valueMetrics: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                purchasePriceMetric
                Divider()
                gainMetric
                Divider()
                performanceMetric
            }
        } else {
            HStack(alignment: .top, spacing: KaraSpacing.medium) {
                purchasePriceMetric
                Divider()
                gainMetric
                Divider()
                performanceMetric
            }
        }
    }

    private var purchasePriceMetric: some View {
        AssetDetailMetric(
            title: "asset-detail.metric.purchase-price",
            value: valuation?.purchaseCost.map {
                VaultFormatters.currency(
                    $0,
                    code: valuation?.purchaseCurrency?.rawValue ?? asset.currencyCode,
                    maximumFractionDigits: 2
                )
            }
        )
    }

    private var gainMetric: some View {
        AssetDetailMetric(
            title: "asset-detail.metric.gain",
            value: valuation?.gainEUR.map {
                VaultFormatters.currency($0, showsPositiveSign: true)
            },
            tint: valuation?.gainEUR.map(performanceColor)
        )
    }

    private var performanceMetric: some View {
        AssetDetailMetric(
            title: "asset-detail.metric.performance",
            value: valuation?.gainPercentage.map {
                VaultFormatters.percentage($0, showsPositiveSign: true)
            },
            tint: valuation?.gainPercentage.map(performanceColor)
        )
    }

    private var completenessCard: some View {
        KaraCard {
            VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                        Text("asset-detail.completeness.title")
                            .font(.headline)
                            .foregroundStyle(theme.ink)

                        Text(LocalizedStringKey(completeness == 1
                            ? "asset-detail.completeness.complete"
                            : "asset-detail.completeness.incomplete"))
                            .font(.caption)
                            .foregroundStyle(theme.muted)
                    }

                    Spacer()

                    Text(completeness, format: .percent.precision(.fractionLength(0)))
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(completeness == 1 ? .green : theme.goldBright)
                }

                ProgressView(value: completeness)
                    .tint(completeness == 1 ? .green : theme.goldBright)
            }
        }
    }

    private var compositionCard: some View {
        KaraCard {
            VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                VaultSectionHeader("asset-detail.composition.title", eyebrow: "asset-detail.composition.eyebrow")

                AssetMetadataRow(title: "asset-detail.field.category") {
                    Text(LocalizedStringKey(asset.category.localizationKey))
                }

                if let metal = asset.metal {
                    AssetMetadataRow(title: "asset-detail.field.metal") {
                        Text(metal.localizedKey)
                    }
                }

                if let weight = asset.weightGrams {
                    AssetMetadataRow(title: "asset-detail.field.gross-weight") {
                        SensitiveValue {
                            Text(VaultFormatters.weight(Decimal(weight), maximumFractionDigits: 3))
                                .monospacedDigit()
                        }
                    }
                }

                if let fineWeight = valuation?.fineWeightGrams {
                    AssetMetadataRow(title: "asset-detail.field.fine-weight") {
                        SensitiveValue {
                            Text(VaultFormatters.weight(fineWeight, maximumFractionDigits: 3))
                                .monospacedDigit()
                        }
                    }
                }

                if let fineness = asset.finenessPermille {
                    AssetMetadataRow(title: "asset-detail.field.purity") {
                        Text("\(VaultFormatters.decimal(Decimal(fineness), maximumFractionDigits: 1)) ‰")
                            .monospacedDigit()
                    }
                } else if let karat = asset.metalKarat {
                    AssetMetadataRow(title: "asset-detail.field.purity") {
                        Text("asset-detail.karat \(karat)")
                            .monospacedDigit()
                    }
                }

                if let gemstoneWeight = asset.gemstoneCaratWeight {
                    AssetMetadataRow(title: "asset-detail.field.gemstone-weight") {
                        Text("\(VaultFormatters.decimal(Decimal(gemstoneWeight))) ct")
                            .monospacedDigit()
                    }
                }

                if let clarity = asset.gemstoneClarity, !clarity.isEmpty {
                    AssetMetadataRow(title: "asset-detail.field.gemstone-clarity") {
                        Text(clarity)
                    }
                }
            }
        }
    }

    private var acquisitionCard: some View {
        KaraCard {
            VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                VaultSectionHeader("asset-detail.acquisition.title", eyebrow: "asset-detail.acquisition.eyebrow")

                if let date = asset.purchaseDate {
                    AssetMetadataRow(title: "asset-detail.field.purchase-date") {
                        Text(date, format: .dateTime.day().month(.wide).year())
                    }
                }

                if let method = asset.acquisitionMethod {
                    AssetMetadataRow(title: "asset-detail.field.acquisition-method") {
                        Text(LocalizedStringKey(method.localizationKey))
                    }
                }

                if let seller = asset.sellerName, !seller.isEmpty {
                    AssetMetadataRow(title: "asset-detail.field.seller") {
                        Text(seller)
                    }
                }

                if let location = asset.storageLocationName, !location.isEmpty {
                    AssetMetadataRow(title: "asset-detail.field.storage") {
                        Text(location)
                    }
                }

                if let invoice = asset.invoiceNumber, !invoice.isEmpty {
                    AssetMetadataRow(title: "asset-detail.field.invoice") {
                        Text(invoice)
                            .font(.body.monospaced())
                    }
                }

                if let serial = asset.serialNumber, !serial.isEmpty {
                    AssetMetadataRow(title: "asset-detail.field.serial-number") {
                        Text(serial)
                            .font(.body.monospaced())
                    }
                }

                AssetMetadataRow(title: "asset-detail.field.updated") {
                    Text(asset.updatedAt, format: .dateTime.day().month(.abbreviated).year().hour().minute())
                }
            }
        }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.small) {
            VaultSectionHeader("asset-detail.tags.title")

            ScrollView(.horizontal) {
                HStack(spacing: KaraSpacing.small) {
                    ForEach(asset.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.ink)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(theme.cobalt.opacity(0.18), in: .capsule)
                            .overlay {
                                Capsule()
                                    .stroke(theme.cobaltBright.opacity(0.28), lineWidth: 1)
                            }
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func documentsCard(attachments assetAttachments: [AssetAttachment]) -> some View {
        KaraCard {
            VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                VaultSectionHeader("asset-detail.documents.title", eyebrow: "asset-detail.documents.eyebrow") {
                    SensitiveValue {
                        Text("asset-detail.documents.count \(assetAttachments.count)")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(theme.muted)
                    }
                }

                if assetAttachments.isEmpty {
                    HStack(spacing: KaraSpacing.medium) {
                        Image(systemName: "doc.badge.plus")
                            .font(.title2)
                            .foregroundStyle(theme.goldBright)
                            .accessibilityHidden(true)

                        Text("asset-detail.documents.empty")
                            .font(.subheadline)
                            .foregroundStyle(theme.muted)
                    }
                } else {
                    ForEach(Array(assetAttachments.prefix(2))) { attachment in
                        HStack(spacing: KaraSpacing.medium) {
                            Image(systemName: attachmentSymbol(attachment.kind))
                                .foregroundStyle(theme.goldBright)
                                .frame(width: 38, height: 38)
                                .background(theme.gold.opacity(0.10), in: .rect(cornerRadius: 11))

                            VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                                Text(attachment.filename)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(theme.ink)
                                    .lineLimit(1)

                                Text(attachment.createdAt, format: .dateTime.day().month(.abbreviated).year())
                                    .font(.caption)
                                    .foregroundStyle(theme.muted)
                            }

                            Spacer()
                        }
                    }
                }

                Button {
                    router.showDocuments(for: asset.id)
                } label: {
                    Label(
                        LocalizedStringKey(assetAttachments.isEmpty
                            ? "asset-detail.documents.add"
                            : "asset-detail.documents.open"),
                        systemImage: "arrow.right"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.glass)
                .accessibilityIdentifier("asset-detail.documents")
            }
        }
    }

    private var completeness: Double {
        let checks = [
            !asset.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            asset.metal != nil,
            asset.weightGrams != nil,
            asset.finenessPermille != nil || asset.metalKarat != nil,
            asset.purchaseDate != nil,
            asset.pricePaidMinorUnits != nil,
            !(asset.storageLocationName ?? "").isEmpty,
        ]
        return Double(checks.filter { $0 }.count) / Double(checks.count)
    }

    private var valuationStatusKey: LocalizedStringKey {
        switch valuation?.status {
        case .invalidQuantity:
            "asset-detail.value.reason.quantity"
        case .missingMetal:
            "asset-detail.value.reason.metal"
        case .missingWeight, .invalidWeight:
            "asset-detail.value.reason.weight"
        case .missingPurity, .invalidPurity:
            "asset-detail.value.reason.purity"
        case .missingEURQuote:
            "asset-detail.value.reason.quote"
        case .valued, .none:
            "asset-detail.value.reason.unavailable"
        }
    }

    private func performanceColor(_ value: Decimal) -> Color {
        if value > 0 { return .green }
        if value < 0 { return .red }
        return theme.muted
    }

    private func attachmentSymbol(_ kind: AssetAttachmentKind) -> String {
        switch kind {
        case .objectPhoto:
            "photo.fill"
        case .invoice:
            "doc.text.fill"
        case .certificate:
            "checkmark.seal.fill"
        case .other:
            "doc.fill"
        }
    }

    private func requestDeletion() {
        deletionRequest = AssetDeletionRequest(id: asset.id, name: asset.name)
        isShowingDeletionConfirmation = true
    }
}

private struct AssetDetailRenderData {
    let attachments: [AssetAttachment]
    let objectPhotoData: Data?

    init(assetID: UUID, attachments: [AssetAttachment]) {
        let matchingAttachments = attachments
            .filter { $0.assetID == assetID }
            .sorted { $0.createdAt > $1.createdAt }

        self.attachments = matchingAttachments
        objectPhotoData = matchingAttachments.first { $0.kind == .objectPhoto }?.data
    }
}

private struct AssetDetailMetric: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: LocalizedStringKey
    let value: String?
    var tint: Color?

    var body: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            if let value {
                SensitiveValue {
                    Text(value)
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(tint ?? theme.ink)
                        .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 0.82 : 0.68)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                }
            } else {
                Text("asset-detail.value.not-provided")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AssetMetadataRow<Value: View>: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: LocalizedStringKey
    let value: Value

    init(
        title: LocalizedStringKey,
        @ViewBuilder value: () -> Value
    ) {
        self.title = title
        self.value = value()
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(theme.muted)

                    value
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.ink)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: KaraSpacing.medium) {
                    Text(title)
                        .font(.subheadline)
                        .foregroundStyle(theme.muted)

                    Spacer(minLength: KaraSpacing.medium)

                    value
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.ink)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .padding(.vertical, KaraSpacing.xSmall)
        .accessibilityElement(children: .combine)
    }
}

private struct AssetDetailHeroImage: View {
    @Environment(KaraTheme.self) private var theme

    let category: AssetCategory
    let photoData: Data?

    var body: some View {
        Group {
            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    theme.surface

                    Image(category.imageName)
                        .resizable()
                        .scaledToFit()
                        .padding(KaraSpacing.xLarge)
                }
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }
}
