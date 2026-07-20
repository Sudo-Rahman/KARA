import Foundation
import SwiftData

enum AssetRepositoryError: Error, Equatable {
    case invalidDraft([AssetDraftValidationError])
}

@MainActor
final class SwiftDataAssetRepository: AssetSaving {
    typealias SaveAction = @MainActor (ModelContext) throws -> Void

    private let modelContext: ModelContext
    private let now: () -> Date
    private let saveAction: SaveAction

    init(
        modelContext: ModelContext,
        now: @escaping () -> Date = Date.init,
        saveAction: @escaping SaveAction = { try $0.save() }
    ) {
        self.modelContext = modelContext
        self.now = now
        self.saveAction = saveAction
    }

    @discardableResult
    func save(draft: AssetDraft, attachments: [AssetAttachmentPayload]) throws -> Asset {
        let validationErrors = draft.validationErrors
        guard validationErrors.isEmpty else {
            throw AssetRepositoryError.invalidDraft(validationErrors)
        }

        let timestamp = now()
        let sellerName = optionalDisplayName(draft.sellerName)
        let storageLocationName = optionalDisplayName(draft.storageLocationName)
        let asset = Asset(
            name: AssetSuggestionNormalizer.displayName(draft.name),
            category: draft.category ?? .custom,
            presetID: draft.presetID,
            quantity: draft.quantity,
            purchaseDate: draft.purchaseDate,
            metal: draft.metal,
            weightGrams: draft.weightGrams,
            metalKarat: draft.metalKarat,
            finenessPermille: draft.finenessPermille,
            gemstoneCaratWeight: draft.gemstoneCaratWeight,
            gemstoneClarity: optionalDisplayName(draft.gemstoneClarity),
            pricePaidMinorUnits: draft.pricePaidMinorUnits,
            currencyCode: draft.currencyCode,
            sellerName: sellerName,
            storageLocationName: storageLocationName,
            invoiceNumber: optionalDisplayName(draft.invoiceNumber),
            createdAt: timestamp,
            updatedAt: timestamp
        )

        do {
            modelContext.insert(asset)

            for payload in attachments {
                modelContext.insert(AssetAttachment(
                    assetID: asset.id,
                    kind: payload.kind,
                    filename: payload.filename,
                    mimeType: payload.mimeType,
                    pageCount: payload.pageCount,
                    data: payload.data,
                    createdAt: timestamp
                ))
            }

            if let sellerName {
                try recordSeller(named: sellerName, at: timestamp)
            }
            if let storageLocationName {
                try recordStorageLocation(named: storageLocationName, at: timestamp)
            }

            try saveAction(modelContext)
            return asset
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func recordSeller(named name: String, at timestamp: Date) throws {
        let normalizedName = AssetSuggestionNormalizer.normalizedName(name)
        let descriptor = FetchDescriptor<SavedSeller>(
            predicate: #Predicate { $0.normalizedName == normalizedName },
            sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)]
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.name = name
            existing.lastUsedAt = timestamp
            existing.usageCount += 1
        } else {
            modelContext.insert(SavedSeller(
                name: name,
                normalizedName: normalizedName,
                lastUsedAt: timestamp,
                usageCount: 1
            ))
        }
    }

    private func recordStorageLocation(named name: String, at timestamp: Date) throws {
        let normalizedName = AssetSuggestionNormalizer.normalizedName(name)
        let descriptor = FetchDescriptor<StorageLocation>(
            predicate: #Predicate { $0.normalizedName == normalizedName },
            sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)]
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.name = name
            existing.lastUsedAt = timestamp
            existing.usageCount += 1
        } else {
            modelContext.insert(StorageLocation(
                name: name,
                normalizedName: normalizedName,
                lastUsedAt: timestamp,
                usageCount: 1
            ))
        }
    }

    private func optionalDisplayName(_ value: String) -> String? {
        let displayName = AssetSuggestionNormalizer.displayName(value)
        return displayName.isEmpty ? nil : displayName
    }
}
