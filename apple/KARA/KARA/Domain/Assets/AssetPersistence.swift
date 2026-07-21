import Foundation
import SwiftData

nonisolated enum AssetRepositoryError: Error, Equatable, Sendable {
    case invalidDraft([AssetDraftValidationError])
    case assetNotFound(UUID)
    case attachmentNotFound(UUID)
    case invalidAttachmentFilename
}

@MainActor
final class SwiftDataAssetRepository: AssetSaving, AssetUpdating, AttachmentManaging {
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
            serialNumber: optionalDisplayName(draft.serialNumber),
            acquisitionMethod: draft.acquisitionMethod,
            tags: AssetTagNormalizer.normalize(draft.tags),
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

    @discardableResult
    func update(assetID: UUID, with draft: AssetDraft) throws -> Asset {
        let validationErrors = draft.validationErrors
        guard validationErrors.isEmpty else {
            throw AssetRepositoryError.invalidDraft(validationErrors)
        }

        guard let asset = try asset(withID: assetID) else {
            throw AssetRepositoryError.assetNotFound(assetID)
        }

        let timestamp = now()
        let previousSellerName = asset.sellerName
        let previousStorageLocationName = asset.storageLocationName
        let sellerName = optionalDisplayName(draft.sellerName)
        let storageLocationName = optionalDisplayName(draft.storageLocationName)

        do {
            asset.name = AssetSuggestionNormalizer.displayName(draft.name)
            asset.category = draft.category ?? .custom
            asset.presetID = draft.presetID
            asset.quantity = draft.quantity
            asset.purchaseDate = draft.purchaseDate
            asset.metal = draft.metal
            asset.weightGrams = draft.weightGrams
            asset.metalKarat = draft.metalKarat
            asset.finenessPermille = draft.finenessPermille
            asset.gemstoneCaratWeight = draft.gemstoneCaratWeight
            asset.gemstoneClarity = optionalDisplayName(draft.gemstoneClarity)
            asset.pricePaidMinorUnits = draft.pricePaidMinorUnits
            asset.currencyCode = draft.currencyCode
            asset.sellerName = sellerName
            asset.storageLocationName = storageLocationName
            asset.invoiceNumber = optionalDisplayName(draft.invoiceNumber)
            asset.serialNumber = optionalDisplayName(draft.serialNumber)
            asset.acquisitionMethod = draft.acquisitionMethod
            asset.tags = AssetTagNormalizer.normalize(draft.tags)
            asset.updatedAt = timestamp

            try reconcileSeller(from: previousSellerName, to: sellerName, at: timestamp)
            try reconcileStorageLocation(
                from: previousStorageLocationName,
                to: storageLocationName,
                at: timestamp
            )

            try saveAction(modelContext)
            return asset
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func attachments(for assetID: UUID) throws -> [AssetAttachment] {
        let descriptor = FetchDescriptor<AssetAttachment>(
            predicate: #Predicate { $0.assetID == assetID },
            sortBy: [
                SortDescriptor(\.createdAt, order: .reverse),
                SortDescriptor(\.filename),
            ]
        )
        return try modelContext.fetch(descriptor)
    }

    @discardableResult
    func add(_ payload: AssetAttachmentPayload, to assetID: UUID) throws -> AssetAttachment {
        guard try asset(withID: assetID) != nil else {
            throw AssetRepositoryError.assetNotFound(assetID)
        }
        let filename = AssetSuggestionNormalizer.displayName(payload.filename)
        guard !filename.isEmpty else {
            throw AssetRepositoryError.invalidAttachmentFilename
        }

        let attachment = AssetAttachment(
            assetID: assetID,
            kind: payload.kind,
            filename: filename,
            mimeType: payload.mimeType,
            pageCount: payload.pageCount,
            data: payload.data,
            createdAt: now()
        )
        do {
            modelContext.insert(attachment)
            try saveAction(modelContext)
            return attachment
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    @discardableResult
    func rename(attachmentID: UUID, for assetID: UUID, to filename: String) throws -> AssetAttachment {
        let normalizedFilename = AssetSuggestionNormalizer.displayName(filename)
        guard !normalizedFilename.isEmpty else {
            throw AssetRepositoryError.invalidAttachmentFilename
        }
        guard let attachment = try attachment(withID: attachmentID, assetID: assetID) else {
            throw AssetRepositoryError.attachmentNotFound(attachmentID)
        }

        do {
            attachment.filename = normalizedFilename
            try saveAction(modelContext)
            return attachment
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func delete(attachmentID: UUID, for assetID: UUID) throws {
        guard let attachment = try attachment(withID: attachmentID, assetID: assetID) else {
            throw AssetRepositoryError.attachmentNotFound(attachmentID)
        }

        do {
            modelContext.delete(attachment)
            try saveAction(modelContext)
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func asset(withID assetID: UUID) throws -> Asset? {
        let descriptor = FetchDescriptor<Asset>(
            predicate: #Predicate { $0.id == assetID }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func attachment(withID attachmentID: UUID, assetID: UUID) throws -> AssetAttachment? {
        let descriptor = FetchDescriptor<AssetAttachment>(
            predicate: #Predicate {
                $0.id == attachmentID && $0.assetID == assetID
            }
        )
        return try modelContext.fetch(descriptor).first
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

    private func reconcileSeller(from previousName: String?, to name: String?, at timestamp: Date) throws {
        let previousKey = previousName.map(AssetSuggestionNormalizer.normalizedName)
        let key = name.map(AssetSuggestionNormalizer.normalizedName)
        guard previousKey != key else {
            if let name, let existing = try savedSeller(normalizedName: key ?? "") {
                existing.name = name
                existing.lastUsedAt = timestamp
            }
            return
        }
        if let previousName {
            try releaseSeller(named: previousName)
        }
        if let name {
            try recordSeller(named: name, at: timestamp)
        }
    }

    private func releaseSeller(named name: String) throws {
        guard let existing = try savedSeller(
            normalizedName: AssetSuggestionNormalizer.normalizedName(name)
        ) else { return }
        if existing.usageCount <= 1 {
            modelContext.delete(existing)
        } else {
            existing.usageCount -= 1
        }
    }

    private func savedSeller(normalizedName: String) throws -> SavedSeller? {
        let descriptor = FetchDescriptor<SavedSeller>(
            predicate: #Predicate { $0.normalizedName == normalizedName },
            sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).first
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

    private func reconcileStorageLocation(
        from previousName: String?,
        to name: String?,
        at timestamp: Date
    ) throws {
        let previousKey = previousName.map(AssetSuggestionNormalizer.normalizedName)
        let key = name.map(AssetSuggestionNormalizer.normalizedName)
        guard previousKey != key else {
            if let name, let existing = try storageLocation(normalizedName: key ?? "") {
                existing.name = name
                existing.lastUsedAt = timestamp
            }
            return
        }
        if let previousName {
            try releaseStorageLocation(named: previousName)
        }
        if let name {
            try recordStorageLocation(named: name, at: timestamp)
        }
    }

    private func releaseStorageLocation(named name: String) throws {
        guard let existing = try storageLocation(
            normalizedName: AssetSuggestionNormalizer.normalizedName(name)
        ) else { return }
        if existing.usageCount <= 1 {
            modelContext.delete(existing)
        } else {
            existing.usageCount -= 1
        }
    }

    private func storageLocation(normalizedName: String) throws -> StorageLocation? {
        let descriptor = FetchDescriptor<StorageLocation>(
            predicate: #Predicate { $0.normalizedName == normalizedName },
            sortBy: [SortDescriptor(\.lastUsedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).first
    }

    private func optionalDisplayName(_ value: String) -> String? {
        let displayName = AssetSuggestionNormalizer.displayName(value)
        return displayName.isEmpty ? nil : displayName
    }
}
