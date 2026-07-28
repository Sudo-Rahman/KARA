import SwiftUI

struct SalesAssetPickerItem: Identifiable {
    let id: UUID
    let name: String
    let category: AssetCategory
    let photoData: Data?
    let detail: String?
    let trailingValue: String?
    let trailingValueIsSensitive: Bool

    init(
        asset: Asset,
        photoData: Data?,
        trailingValue: String?,
        trailingValueIsSensitive: Bool
    ) {
        id = asset.id
        name = asset.name
        category = asset.category
        self.photoData = photoData
        detail = SalesAssetIdentification.detail(for: asset)
        self.trailingValue = trailingValue
        self.trailingValueIsSensitive = trailingValueIsSensitive
    }

    func matches(_ query: String) -> Bool {
        let normalizedQuery = query.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
        .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return true }

        return [name, detail]
            .compactMap { $0 }
            .joined(separator: " ")
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            .contains(normalizedQuery)
    }
}

enum SalesAssetIdentification {
    static func detail(for asset: Asset) -> String? {
        let weightGrams: Decimal?
        if let value = asset.weightGrams, value.isFinite {
            weightGrams = Decimal(
                string: String(value),
                locale: Locale(identifier: "en_US_POSIX")
            )
        } else {
            weightGrams = nil
        }

        return detail(
            serialNumber: asset.serialNumber,
            weightGrams: weightGrams,
            storageLocation: asset.storageLocationName,
            purchaseDate: asset.purchaseDate
        )
    }

    static func detail(for line: SaleLine) -> String? {
        detail(
            serialNumber: line.serialNumberSnapshot,
            weightGrams: line.weightGramsSnapshot,
            storageLocation: line.storageLocationNameSnapshot,
            purchaseDate: line.purchaseDateSnapshot
        )
    }

    private static func detail(
        serialNumber: String?,
        weightGrams: Decimal?,
        storageLocation: String?,
        purchaseDate: Date?
    ) -> String? {
        var values: [String] = []

        if let serialNumber = nonBlank(serialNumber) {
            values.append(
                SalesCopy.formatted("sales.asset.serial", serialNumber)
            )
        }

        if let weightGrams, weightGrams > 0 {
            values.append(VaultFormatters.weight(weightGrams))
        } else if let storageLocation = nonBlank(storageLocation) {
            values.append(storageLocation)
        } else if let purchaseDate {
            values.append(
                SalesCopy.formatted(
                    "sales.asset.purchased",
                    purchaseDate.formatted(
                        .dateTime.day().month(.abbreviated).year()
                    )
                )
            )
        }

        return values.isEmpty ? nil : values.joined(separator: " · ")
    }

    private static func nonBlank(_ value: String?) -> String? {
        guard let value = value?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty
        else {
            return nil
        }
        return value
    }

}

struct SalesAssetPicker: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Binding var selectedAssetID: UUID?

    let items: [SalesAssetPickerItem]
    let accessibilityIdentifier: String

    @State private var isPickerPresented = false
    @State private var searchText = ""

    var body: some View {
        Group {
            if let selectedItem {
                Button {
                    guard items.count > 1 else { return }
                    isPickerPresented = true
                } label: {
                    selectedCard(selectedItem)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(.isSelected)
                .accessibilityHint(
                    items.count > 1
                        ? SalesCopy.text("sales.asset.change.hint")
                        : Text("")
                )
            }
        }
        .accessibilityIdentifier(accessibilityIdentifier)
        .sheet(isPresented: $isPickerPresented) {
            pickerSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var selectedItem: SalesAssetPickerItem? {
        guard let selectedAssetID else { return nil }
        return items.first { $0.id == selectedAssetID }
    }

    private var filteredItems: [SalesAssetPickerItem] {
        items.filter { $0.matches(searchText) }
    }

    private func selectedCard(_ item: SalesAssetPickerItem) -> some View {
        HStack(alignment: .center, spacing: KaraSpacing.medium) {
            AssetArtworkView(
                category: item.category,
                photoData: item.photoData,
                size: dynamicTypeSize.isAccessibilitySize ? 58 : 52
            )

            identity(for: item)

            Spacer(minLength: KaraSpacing.small)

            VStack(alignment: .trailing, spacing: KaraSpacing.xSmall) {
                if let value = item.trailingValue {
                    trailingValue(
                        value,
                        isSensitive: item.trailingValueIsSensitive
                    )
                }

                if items.count > 1 {
                    SalesCopy.text("sales.asset.change")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.goldBright)
                }
            }
        }
        .padding(KaraSpacing.medium)
        .background(theme.background.opacity(0.72), in: .rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(theme.muted.opacity(0.18), lineWidth: 1)
        }
        .contentShape(.rect)
    }

    private var pickerSheet: some View {
        NavigationStack {
            Group {
                if items.count >= 8 {
                    pickerList
                        .searchable(
                            text: $searchText,
                            placement: .navigationBarDrawer(displayMode: .always),
                            prompt: SalesCopy.text("sales.asset.search")
                        )
                } else {
                    pickerList
                }
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle(SalesCopy.string("sales.asset.choose"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        isPickerPresented = false
                    } label: {
                        SalesCopy.text("sales.action.close")
                    }
                }
            }
        }
        .onDisappear {
            searchText = ""
        }
    }

    private var pickerList: some View {
        ScrollView {
            LazyVStack(spacing: KaraSpacing.small) {
                ForEach(filteredItems) { item in
                    pickerRow(item)
                }
            }
            .padding(.horizontal, KaraSpacing.medium)
            .padding(.vertical, KaraSpacing.medium)
        }
        .scrollIndicators(.hidden)
    }

    private func pickerRow(_ item: SalesAssetPickerItem) -> some View {
        let selected = item.id == selectedAssetID

        return Button {
            selectedAssetID = item.id
            isPickerPresented = false
        } label: {
            HStack(alignment: .center, spacing: KaraSpacing.medium) {
                AssetArtworkView(
                    category: item.category,
                    photoData: item.photoData,
                    size: 52
                )

                identity(for: item)

                Spacer(minLength: KaraSpacing.small)

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(theme.cobaltBright)
                        .accessibilityHidden(true)
                } else if let value = item.trailingValue {
                    trailingValue(
                        value,
                        isSensitive: item.trailingValueIsSensitive
                    )
                }
            }
            .padding(KaraSpacing.medium)
            .background(
                selected
                    ? theme.cobalt.opacity(0.18)
                    : theme.surface,
                in: .rect(cornerRadius: 16)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        selected
                            ? theme.cobaltBright.opacity(0.62)
                            : theme.muted.opacity(0.16),
                        lineWidth: selected ? 1.5 : 1
                    )
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier(
            "\(accessibilityIdentifier).\(item.id.uuidString)"
        )
    }

    private func identity(for item: SalesAssetPickerItem) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: item.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.ink)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)

            if let detail = item.detail {
                SensitiveValue {
                    Text(verbatim: detail)
                        .font(.caption)
                        .foregroundStyle(theme.muted)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func trailingValue(
        _ value: String,
        isSensitive: Bool
    ) -> some View {
        if isSensitive {
            SensitiveValue {
                trailingValueText(value)
            }
        } else {
            trailingValueText(value)
        }
    }

    private func trailingValueText(_ value: String) -> some View {
        Text(verbatim: value)
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .foregroundStyle(theme.ink)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}
