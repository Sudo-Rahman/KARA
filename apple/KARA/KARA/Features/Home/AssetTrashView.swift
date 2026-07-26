import SwiftData
import SwiftUI

struct AssetTrashView: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Asset> { $0.deletedAt != nil }) private var assets: [Asset]
    @Query private var attachments: [AssetAttachment]

    @State private var pendingPermanentDeletion: Asset?
    @State private var isConfirmingDeleteAll = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if sortedAssets.isEmpty {
                emptyState
            } else {
                List {
                    Section {
                        ForEach(sortedAssets) { asset in
                            trashRow(asset)
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        restore(asset)
                                    } label: {
                                        Label("settings.trash.restore", systemImage: "arrow.uturn.backward")
                                    }
                                    .tint(.green)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        pendingPermanentDeletion = asset
                                    } label: {
                                        Label("settings.trash.delete.action", systemImage: "trash")
                                    }
                                    .tint(.red)
                                    .accessibilityIdentifier("settings.trash.delete.\(asset.id.uuidString)")
                                }
                        }
                    } footer: {
                        Text("settings.trash.retention")
                    }
                    .listRowBackground(theme.surface)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle("settings.trash.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !sortedAssets.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        isConfirmingDeleteAll = true
                    } label: {
                        Label("settings.trash.delete-all", systemImage: "trash")
                    }
                    .foregroundStyle(.red)
                    .accessibilityIdentifier("settings.trash.delete-all")
                }
            }
        }
        .confirmationDialog(
            "settings.trash.delete.confirmation.title",
            isPresented: permanentDeletionIsPresented,
            titleVisibility: .visible
        ) {
            Button("settings.trash.delete", role: .destructive) {
                permanentlyDeletePendingAsset()
            }
            Button("settings.trash.cancel", role: .cancel) {
                pendingPermanentDeletion = nil
            }
        } message: {
            Text("settings.trash.delete.confirmation.body")
        }
        .confirmationDialog(
            "settings.trash.delete-all.confirmation.title",
            isPresented: $isConfirmingDeleteAll,
            titleVisibility: .visible
        ) {
            Button("settings.trash.delete-all", role: .destructive) {
                permanentlyDeleteAllAssets()
            }
            .accessibilityIdentifier("settings.trash.delete-all.confirm")

            Button("settings.trash.cancel", role: .cancel) {}
        } message: {
            Text("settings.trash.delete-all.confirmation.body \(sortedAssets.count)")
        }
        .alert("settings.trash.error.title", isPresented: errorIsPresented) {
            Button("settings.trash.error.dismiss", role: .cancel) {
                errorMessage = nil
            }
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
        .accessibilityIdentifier("settings.trash.screen")
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("settings.trash.empty.title", systemImage: "trash")
        } description: {
            Text("settings.trash.empty.detail")
        }
        .foregroundStyle(theme.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func trashRow(_ asset: Asset) -> some View {
        HStack(spacing: KaraSpacing.medium) {
            AssetArtworkView(
                category: asset.category,
                photoData: firstObjectPhotoData(for: asset.id, attachments: attachments),
                size: 48
            )

            VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                Text(asset.name)
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                    .lineLimit(2)

                Text(LocalizedStringKey(asset.category.localizationKey))
                    .font(.caption)
                    .foregroundStyle(theme.muted)

                if let expirationDate = expirationDate(for: asset) {
                    HStack(spacing: KaraSpacing.xSmall) {
                        Text("settings.trash.expires")
                        Text(expirationDate, format: .dateTime.day().month(.abbreviated).year())
                    }
                    .font(.caption2)
                    .foregroundStyle(theme.muted)
                }
            }

            Spacer(minLength: KaraSpacing.small)

            Menu {
                Button {
                    restore(asset)
                } label: {
                    Label("settings.trash.restore", systemImage: "arrow.uturn.backward")
                }

                Button(role: .destructive) {
                    pendingPermanentDeletion = asset
                } label: {
                    Label("settings.trash.delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .accessibilityLabel(Text("settings.trash.actions"))
            .accessibilityIdentifier("settings.trash.actions.\(asset.id.uuidString)")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.trash.asset.\(asset.id.uuidString)")
    }

    private var sortedAssets: [Asset] {
        assets.sorted {
            ($0.deletedAt ?? .distantPast) > ($1.deletedAt ?? .distantPast)
        }
    }

    private var repository: SwiftDataAssetRepository {
        SwiftDataAssetRepository(modelContext: modelContext)
    }

    private var permanentDeletionIsPresented: Binding<Bool> {
        Binding(
            get: { pendingPermanentDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    pendingPermanentDeletion = nil
                }
            }
        )
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    private func expirationDate(for asset: Asset) -> Date? {
        guard let deletedAt = asset.deletedAt else { return nil }
        return Calendar.current.date(
            byAdding: .day,
            value: AssetTrashPolicy.retentionDays,
            to: deletedAt
        )
    }

    private func restore(_ asset: Asset) {
        performTrashUpdate {
            try repository.restore(assetID: asset.id)
        }
    }

    private func permanentlyDeletePendingAsset() {
        guard let asset = pendingPermanentDeletion else { return }
        pendingPermanentDeletion = nil

        performTrashUpdate {
            try repository.permanentlyDelete(assetID: asset.id)
        }
    }

    private func permanentlyDeleteAllAssets() {
        performTrashUpdate {
            try repository.permanentlyDeleteAllTrashedAssets()
        }
    }

    private func performTrashUpdate(_ update: () throws -> Void) {
        do {
            try update()
        } catch {
            errorMessage = String(localized: "settings.trash.error.body")
        }
    }
}
