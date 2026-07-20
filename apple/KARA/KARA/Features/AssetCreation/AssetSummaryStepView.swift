import SwiftUI
import UIKit

struct AssetSummaryStepView: View {
    @Environment(KaraTheme.self) private var theme

    let state: AssetCreationState
    let onEdit: () -> Void
    let onSaved: () -> Void

    var body: some View {
        AssetStepScaffold(
            step: .summary,
            navigationTitle: "summary.navigation-title",
            title: "summary.title",
            message: "summary.body"
        ) {
            mediaSection
            summaryHero
            informationSection

            if hasPurchaseInformation {
                purchaseSection
            }

            if let issue = state.issue {
                AssetIssueBanner(issue: issue, onDismiss: state.dismissIssue)
                    .accessibilityIdentifier("summary.error")
            }
        } footer: {
            VStack(spacing: KaraSpacing.small) {
                Button(action: save) {
                    Group {
                        if state.isSaving {
                            ProgressView()
                        } else {
                            Label("summary.save", systemImage: "lock.fill")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.karaPrimaryAction(isLoading: state.isSaving))
                .disabled(state.isSaving)
                .accessibilityIdentifier("summary.save")

                Button(action: onEdit) {
                    Label("summary.edit", systemImage: "pencil")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.glass)
                .accessibilityIdentifier("summary.edit")
            }
        }
    }

    @ViewBuilder
    private var mediaSection: some View {
        if state.objectPhotoData != nil || state.invoiceDocument != nil {
            VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                AssetSectionTitle("summary.section.documents")

                if let data = state.objectPhotoData, let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(16 / 10, contentMode: .fit)
                        .clipped()
                        .clipShape(.rect(cornerRadius: 16))
                        .accessibilityLabel(Text("summary.photo.accessibility"))
                        .accessibilityIdentifier("summary.photo")
                }

                if let invoice = state.invoiceDocument {
                    AssetFieldSurface {
                        Label {
                            VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                                Text(invoice.filename)
                                    .font(.headline)
                                    .foregroundStyle(theme.ink)
                                    .lineLimit(2)
                                Text("invoice.pages \(invoice.pageCount)")
                                    .font(.subheadline)
                                    .foregroundStyle(theme.muted)
                            }
                        } icon: {
                            Image(systemName: "doc.richtext.fill")
                                .foregroundStyle(theme.goldBright)
                        }
                    }
                    .accessibilityIdentifier("summary.invoice")
                }
            }
        }
    }

    private var summaryHero: some View {
        HStack(spacing: KaraSpacing.medium) {
            Image(state.draft.category?.imageName ?? AssetCategory.custom.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 78, height: 78)
                .clipShape(.rect(cornerRadius: 14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                Text(state.draft.name)
                    .font(theme.displayFont(size: 22, relativeTo: .title2))
                    .foregroundStyle(theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                if let category = state.draft.category {
                    Text(LocalizedStringKey(category.localizationKey))
                        .font(.subheadline)
                        .foregroundStyle(theme.muted)
                }

                if state.draft.quantity > 1 {
                    Text("×\(state.draft.quantity)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(theme.goldBright)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(KaraSpacing.medium)
        .background(theme.surface, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("summary.asset")
    }

    private var informationSection: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.medium) {
            AssetSectionTitle("summary.section.details")

            AssetFieldSurface {
                if let metal = state.draft.metal {
                    LabeledContent("details.metal") {
                        Text(metal.localizedKey)
                    }
                }

                if let weight = state.draft.weightGrams {
                    if state.draft.metal != nil { Divider() }
                    LabeledContent("characteristics.weight.title") {
                        Text("\(weight.formatted(.number.precision(.fractionLength(0 ... 4)))) g")
                            .monospacedDigit()
                    }
                }

                if state.draft.metalKarat != nil || state.draft.finenessPermille != nil {
                    if state.draft.metal != nil || state.draft.weightGrams != nil { Divider() }
                    LabeledContent("summary.purity") {
                        purityText
                    }
                }

                if let gemstoneWeight = state.draft.gemstoneCaratWeight {
                    if hasCompositionInformationBeforeGemstones { Divider() }
                    LabeledContent("details.gemstone-carat") {
                        Text("\(gemstoneWeight.formatted(.number.precision(.fractionLength(0 ... 3)))) ct")
                            .monospacedDigit()
                    }
                }

                if !state.draft.gemstoneClarity.isEmpty {
                    if hasCompositionInformationBeforeGemstones || state.draft.gemstoneCaratWeight != nil {
                        Divider()
                    }
                    LabeledContent("details.gemstone-clarity", value: state.draft.gemstoneClarity)
                }
            }
        }
    }

    private var purchaseSection: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.medium) {
            AssetSectionTitle("summary.section.purchase")

            AssetFieldSurface {
                if let date = state.draft.purchaseDate {
                    LabeledContent("details.purchase-date") {
                        Text(date, format: .dateTime.day().month(.wide).year())
                    }
                }

                if let minorUnits = state.draft.pricePaidMinorUnits,
                   let amount = MoneyConverter.decimalAmount(
                       from: minorUnits,
                       currencyCode: state.draft.currencyCode
                   ) {
                    if state.draft.purchaseDate != nil { Divider() }
                    LabeledContent("details.price") {
                        Text(amount, format: .currency(code: state.draft.currencyCode))
                            .monospacedDigit()
                    }
                }

                if !state.draft.sellerName.isEmpty {
                    if state.draft.purchaseDate != nil || state.draft.pricePaidMinorUnits != nil {
                        Divider()
                    }
                    LabeledContent("details.seller", value: state.draft.sellerName)
                }

                if !state.draft.storageLocationName.isEmpty {
                    if state.draft.purchaseDate != nil
                        || state.draft.pricePaidMinorUnits != nil
                        || !state.draft.sellerName.isEmpty {
                        Divider()
                    }
                    LabeledContent("details.storage-location", value: state.draft.storageLocationName)
                }

                if !state.draft.invoiceNumber.isEmpty {
                    if state.draft.purchaseDate != nil
                        || state.draft.pricePaidMinorUnits != nil
                        || !state.draft.sellerName.isEmpty
                        || !state.draft.storageLocationName.isEmpty {
                        Divider()
                    }
                    LabeledContent("details.invoice-number", value: state.draft.invoiceNumber)
                }
            }
        }
    }

    @ViewBuilder
    private var purityText: some View {
        if let karat = state.draft.metalKarat, let fineness = state.draft.finenessPermille {
            Text("\(karat) ct · \(fineness.formatted(.number.precision(.fractionLength(0 ... 2)))) ‰")
                .monospacedDigit()
        } else if let karat = state.draft.metalKarat {
            Text("\(karat) ct")
                .monospacedDigit()
        } else if let fineness = state.draft.finenessPermille {
            Text("\(fineness.formatted(.number.precision(.fractionLength(0 ... 2)))) ‰")
                .monospacedDigit()
        }
    }

    private var hasPurchaseInformation: Bool {
        state.draft.purchaseDate != nil
            || state.draft.pricePaidMinorUnits != nil
            || !state.draft.sellerName.isEmpty
            || !state.draft.storageLocationName.isEmpty
            || !state.draft.invoiceNumber.isEmpty
    }

    private var hasCompositionInformationBeforeGemstones: Bool {
        state.draft.metal != nil
            || state.draft.weightGrams != nil
            || state.draft.metalKarat != nil
            || state.draft.finenessPermille != nil
    }

    private func save() {
        guard state.save() != nil else { return }
        onSaved()
    }
}
