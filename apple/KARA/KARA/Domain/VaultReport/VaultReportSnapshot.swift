import Foundation

nonisolated struct VaultReportSnapshot: Equatable, Sendable {
    let assets: [VaultReportAssetSnapshot]
    let purchaseCosts: [VaultReportPurchaseCost]
    let valuation: VaultReportValuationSnapshot
    let valuationAsOf: Date

    var recordCount: Int { assets.count }

    var objectCount: Int {
        assets.reduce(into: 0) { count, asset in
            count += max(0, asset.quantity)
        }
    }
}

nonisolated struct VaultReportPurchaseCost: Equatable, Sendable {
    let currencyCode: String
    let amount: Decimal
}

nonisolated struct VaultReportValuationSnapshot: Equatable, Sendable {
    let totalEstimatedValueEUR: Decimal
    let totalPurchaseCostEUR: Decimal?
    let totalGainEUR: Decimal?
    let gainPercentage: Decimal?
    let coverage: PortfolioCoverage
}

nonisolated struct VaultReportAssetSnapshot: Equatable, Identifiable, Sendable {
    let id: UUID
    let name: String
    let category: AssetCategory
    let preset: VaultReportPresetSnapshot?
    let quantity: Int
    let purchaseDate: Date?
    let metal: PreciousMetal?
    let weightGrams: Decimal?
    let metalKarat: Int?
    let finenessPermille: Decimal?
    let gemstoneCaratWeight: Decimal?
    let gemstoneClarity: String?
    let pricePaid: VaultReportMoney?
    let sellerName: String?
    let storageLocationName: String?
    let invoiceNumber: String?
    let serialNumber: String?
    let acquisitionMethod: AssetAcquisitionMethod?
    let tags: [String]
    let createdAt: Date
    let updatedAt: Date
    let valuation: VaultReportAssetValuationSnapshot
    let attachments: [VaultReportAttachmentSnapshot]
}

nonisolated struct VaultReportPresetSnapshot: Equatable, Sendable {
    let localizationKey: String
    let fallbackName: String
}

nonisolated struct VaultReportMoney: Equatable, Sendable {
    let amount: Decimal
    let currencyCode: String
}

nonisolated struct VaultReportAssetValuationSnapshot: Equatable, Sendable {
    let estimatedValueEUR: Decimal?
    let gainEUR: Decimal?
    let gainPercentage: Decimal?
}

nonisolated struct VaultReportAttachmentSnapshot: Equatable, Identifiable, Sendable {
    let id: UUID
    let kind: AssetAttachmentKind
    let filename: String
    let mimeType: String
    let pageCount: Int?
    let byteCount: Int64?
    let data: Data
    let createdAt: Date
}

@MainActor
enum VaultReportSnapshotAssembler {
    private static let cooperativeBatchSize = 50

    static func make(
        assets: [Asset],
        attachments: [AssetAttachment],
        valuation: PortfolioValuation,
        valuationAsOf: Date
    ) -> VaultReportSnapshot {
        let valuationByAssetID = valuationsByAssetID(from: valuation.assetValuations)
        let activeAssets = sortedActiveAssets(
            from: assets,
            valuations: valuationByAssetID
        )
        let activeAssetIDs = Set(activeAssets.map(\.id))

        var attachmentsByAssetID: [UUID: [VaultReportAttachmentSnapshot]] = [:]
        for attachment in attachments {
            append(
                attachment,
                activeAssetIDs: activeAssetIDs,
                to: &attachmentsByAssetID
            )
        }
        for assetID in Array(attachmentsByAssetID.keys) {
            sortAttachments(for: assetID, in: &attachmentsByAssetID)
        }

        let reportAssets = activeAssets.map { asset in
            assetSnapshot(
                for: asset,
                valuation: valuationByAssetID[asset.id],
                attachments: attachmentsByAssetID[asset.id] ?? []
            )
        }

        return report(
            assets: reportAssets,
            purchaseCosts: purchaseCosts(for: reportAssets),
            valuation: valuation,
            valuationAsOf: valuationAsOf
        )
    }

    static func makeCooperatively(
        assets: [Asset],
        attachments: [AssetAttachment],
        valuation: PortfolioValuation,
        valuationAsOf: Date
    ) async throws -> VaultReportSnapshot {
        try Task.checkCancellation()
        await Task.yield()
        try Task.checkCancellation()

        var valuationByAssetID: [UUID: AssetValuation] = [:]
        valuationByAssetID.reserveCapacity(valuation.assetValuations.count)
        for (index, assetValuation) in valuation.assetValuations.enumerated() {
            insert(assetValuation, into: &valuationByAssetID)
            try await cooperate(after: index + 1)
        }
        try Task.checkCancellation()

        var activeAssets: [Asset] = []
        activeAssets.reserveCapacity(assets.count)
        for (index, asset) in assets.enumerated() {
            if isHeld(asset, valuation: valuationByAssetID[asset.id]) {
                activeAssets.append(asset)
            }
            try await cooperate(after: index + 1)
        }
        activeAssets.sort(by: isNewer)
        try Task.checkCancellation()

        let activeAssetIDs = Set(activeAssets.map(\.id))
        var attachmentsByAssetID: [UUID: [VaultReportAttachmentSnapshot]] = [:]
        for (index, attachment) in attachments.enumerated() {
            append(
                attachment,
                activeAssetIDs: activeAssetIDs,
                to: &attachmentsByAssetID
            )
            try await cooperate(after: index + 1)
        }

        for (index, assetID) in Array(attachmentsByAssetID.keys).enumerated() {
            sortAttachments(for: assetID, in: &attachmentsByAssetID)
            try await cooperate(after: index + 1)
        }
        try Task.checkCancellation()

        var reportAssets: [VaultReportAssetSnapshot] = []
        reportAssets.reserveCapacity(activeAssets.count)
        var purchaseCostAmounts: [String: Decimal] = [:]
        for (index, asset) in activeAssets.enumerated() {
            let reportAsset = assetSnapshot(
                for: asset,
                valuation: valuationByAssetID[asset.id],
                attachments: attachmentsByAssetID[asset.id] ?? []
            )
            reportAssets.append(reportAsset)
            addPurchaseCost(for: reportAsset, to: &purchaseCostAmounts)
            try await cooperate(after: index + 1)
        }
        try Task.checkCancellation()

        return report(
            assets: reportAssets,
            purchaseCosts: purchaseCosts(from: purchaseCostAmounts),
            valuation: valuation,
            valuationAsOf: valuationAsOf
        )
    }

    private static func sortedActiveAssets(
        from assets: [Asset],
        valuations: [UUID: AssetValuation]
    ) -> [Asset] {
        assets
            .filter { isHeld($0, valuation: valuations[$0.id]) }
            .sorted(by: isNewer)
    }

    private static func valuationsByAssetID(
        from valuations: [AssetValuation]
    ) -> [UUID: AssetValuation] {
        var valuationsByAssetID: [UUID: AssetValuation] = [:]
        valuationsByAssetID.reserveCapacity(valuations.count)
        for valuation in valuations {
            insert(valuation, into: &valuationsByAssetID)
        }
        return valuationsByAssetID
    }

    private static func isHeld(_ asset: Asset, valuation: AssetValuation?) -> Bool {
        guard asset.deletedAt == nil else { return false }
        return (valuation?.quantity ?? asset.quantity) > 0
    }

    private static func append(
        _ attachment: AssetAttachment,
        activeAssetIDs: Set<UUID>,
        to attachmentsByAssetID: inout [UUID: [VaultReportAttachmentSnapshot]]
    ) {
        guard activeAssetIDs.contains(attachment.assetID) else { return }

        attachmentsByAssetID[attachment.assetID, default: []].append(
            VaultReportAttachmentSnapshot(
                id: attachment.id,
                kind: attachment.kind,
                filename: attachment.filename,
                mimeType: attachment.mimeType,
                pageCount: attachment.pageCount,
                byteCount: attachment.dataByteCount,
                data: attachment.data,
                createdAt: attachment.createdAt
            )
        )
    }

    private static func sortAttachments(
        for assetID: UUID,
        in attachmentsByAssetID: inout [UUID: [VaultReportAttachmentSnapshot]]
    ) {
        attachmentsByAssetID[assetID]?.sort(by: isNewer)
    }

    private static func insert(
        _ assetValuation: AssetValuation,
        into valuationByAssetID: inout [UUID: AssetValuation]
    ) {
        guard valuationByAssetID[assetValuation.assetID] == nil else { return }
        valuationByAssetID[assetValuation.assetID] = assetValuation
    }

    private static func assetSnapshot(
        for asset: Asset,
        valuation: AssetValuation?,
        attachments: [VaultReportAttachmentSnapshot]
    ) -> VaultReportAssetSnapshot {
        VaultReportAssetSnapshot(
            id: asset.id,
            name: asset.name,
            category: asset.category,
            preset: AssetCatalog.preset(id: asset.presetID).map {
                VaultReportPresetSnapshot(
                    localizationKey: $0.localizationKey,
                    fallbackName: $0.name
                )
            },
            quantity: valuation?.quantity ?? asset.quantity,
            purchaseDate: asset.purchaseDate,
            metal: asset.metal,
            weightGrams: decimal(asset.weightGrams),
            metalKarat: asset.metalKarat,
            finenessPermille: decimal(asset.finenessPermille),
            gemstoneCaratWeight: decimal(asset.gemstoneCaratWeight),
            gemstoneClarity: nonBlank(asset.gemstoneClarity),
            pricePaid: money(for: asset, valuation: valuation),
            sellerName: nonBlank(asset.sellerName),
            storageLocationName: nonBlank(asset.storageLocationName),
            invoiceNumber: nonBlank(asset.invoiceNumber),
            serialNumber: nonBlank(asset.serialNumber),
            acquisitionMethod: asset.acquisitionMethod,
            tags: asset.tags.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
            createdAt: asset.createdAt,
            updatedAt: asset.updatedAt,
            valuation: VaultReportAssetValuationSnapshot(
                estimatedValueEUR: valuation?.estimatedValueEUR,
                gainEUR: valuation?.gainEUR,
                gainPercentage: valuation?.gainPercentage
            ),
            attachments: attachments
        )
    }

    private static func report(
        assets: [VaultReportAssetSnapshot],
        purchaseCosts: [VaultReportPurchaseCost],
        valuation: PortfolioValuation,
        valuationAsOf: Date
    ) -> VaultReportSnapshot {
        return VaultReportSnapshot(
            assets: assets,
            purchaseCosts: purchaseCosts,
            valuation: VaultReportValuationSnapshot(
                totalEstimatedValueEUR: valuation.totalEstimatedValueEUR,
                totalPurchaseCostEUR: valuation.totalPurchaseCostEUR,
                totalGainEUR: valuation.totalGainEUR,
                gainPercentage: valuation.gainPercentage,
                coverage: valuation.coverage
            ),
            valuationAsOf: valuationAsOf
        )
    }

    private static func cooperate(after processedCount: Int) async throws {
        guard processedCount.isMultiple(of: cooperativeBatchSize) else { return }
        try Task.checkCancellation()
        await Task.yield()
        try Task.checkCancellation()
    }

    private static func money(
        for asset: Asset,
        valuation: AssetValuation?
    ) -> VaultReportMoney? {
        if let amount = valuation?.purchaseCost,
           let currency = valuation?.purchaseCurrency {
            return VaultReportMoney(amount: amount, currencyCode: currency.rawValue)
        }

        guard let minorUnits = asset.pricePaidMinorUnits,
              let amount = MoneyConverter.decimalAmount(
                  from: minorUnits,
                  currencyCode: asset.currencyCode
              )
        else {
            return nil
        }
        return VaultReportMoney(amount: amount, currencyCode: asset.currencyCode)
    }

    private static func purchaseCosts(
        for assets: [VaultReportAssetSnapshot]
    ) -> [VaultReportPurchaseCost] {
        var amountsByCurrency: [String: Decimal] = [:]
        for asset in assets {
            addPurchaseCost(for: asset, to: &amountsByCurrency)
        }
        return purchaseCosts(from: amountsByCurrency)
    }

    private static func addPurchaseCost(
        for asset: VaultReportAssetSnapshot,
        to amountsByCurrency: inout [String: Decimal]
    ) {
        guard let pricePaid = asset.pricePaid else { return }
        amountsByCurrency[pricePaid.currencyCode, default: 0] += pricePaid.amount
    }

    private static func purchaseCosts(
        from amountsByCurrency: [String: Decimal]
    ) -> [VaultReportPurchaseCost] {
        return amountsByCurrency
            .map {
                VaultReportPurchaseCost(
                    currencyCode: $0.key,
                    amount: $0.value
                )
            }
            .sorted { $0.currencyCode < $1.currencyCode }
    }

    private static func decimal(_ value: Double?) -> Decimal? {
        guard let value, value.isFinite else { return nil }
        return Decimal(
            string: String(value),
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    private static func nonBlank(_ value: String?) -> String? {
        guard let value,
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }
        return value
    }

    private static func isNewer(_ lhs: Asset, _ rhs: Asset) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func isNewer(
        _ lhs: VaultReportAttachmentSnapshot,
        _ rhs: VaultReportAttachmentSnapshot
    ) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
