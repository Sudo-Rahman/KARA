import Foundation
import SwiftData

@Model
final class Asset {
    var id: UUID = UUID()
    var name: String = ""
    var categoryRawValue: String = AssetCategory.custom.rawValue
    var presetID: String?
    var quantity: Int = 1
    var purchaseDate: Date?
    var metalRawValue: String?
    var weightGrams: Double?
    var metalKarat: Int?
    var finenessPermille: Double?
    var gemstoneCaratWeight: Double?
    var gemstoneClarity: String?
    var pricePaidMinorUnits: Int64?
    var currencyCode: String = "EUR"
    var sellerName: String?
    var storageLocationName: String?
    var invoiceNumber: String?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var category: AssetCategory {
        get { AssetCategory(rawValue: categoryRawValue) ?? .custom }
        set { categoryRawValue = newValue.rawValue }
    }

    var metal: PreciousMetal? {
        get { metalRawValue.flatMap(PreciousMetal.init(rawValue:)) }
        set { metalRawValue = newValue?.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String = "",
        category: AssetCategory = .custom,
        presetID: String? = nil,
        quantity: Int = 1,
        purchaseDate: Date? = nil,
        metal: PreciousMetal? = nil,
        weightGrams: Double? = nil,
        metalKarat: Int? = nil,
        finenessPermille: Double? = nil,
        gemstoneCaratWeight: Double? = nil,
        gemstoneClarity: String? = nil,
        pricePaidMinorUnits: Int64? = nil,
        currencyCode: String = "EUR",
        sellerName: String? = nil,
        storageLocationName: String? = nil,
        invoiceNumber: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        categoryRawValue = category.rawValue
        self.presetID = presetID
        self.quantity = quantity
        self.purchaseDate = purchaseDate
        metalRawValue = metal?.rawValue
        self.weightGrams = weightGrams
        self.metalKarat = metalKarat
        self.finenessPermille = finenessPermille
        self.gemstoneCaratWeight = gemstoneCaratWeight
        self.gemstoneClarity = gemstoneClarity
        self.pricePaidMinorUnits = pricePaidMinorUnits
        self.currencyCode = currencyCode
        self.sellerName = sellerName
        self.storageLocationName = storageLocationName
        self.invoiceNumber = invoiceNumber
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class AssetAttachment {
    var id: UUID = UUID()
    var assetID: UUID = UUID()
    var kindRawValue: String = AssetAttachmentKind.objectPhoto.rawValue
    var filename: String = ""
    var mimeType: String = "application/octet-stream"
    var pageCount: Int?
    @Attribute(.externalStorage) var data: Data = Data()
    var createdAt: Date = Date()

    var kind: AssetAttachmentKind {
        get { AssetAttachmentKind(rawValue: kindRawValue) ?? .objectPhoto }
        set { kindRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        assetID: UUID = UUID(),
        kind: AssetAttachmentKind = .objectPhoto,
        filename: String = "",
        mimeType: String = "application/octet-stream",
        pageCount: Int? = nil,
        data: Data = Data(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.assetID = assetID
        kindRawValue = kind.rawValue
        self.filename = filename
        self.mimeType = mimeType
        self.pageCount = pageCount
        self.data = data
        self.createdAt = createdAt
    }
}

@Model
final class SavedSeller {
    var id: UUID = UUID()
    var name: String = ""
    var normalizedName: String = ""
    var lastUsedAt: Date = Date()
    var usageCount: Int = 0

    init(
        id: UUID = UUID(),
        name: String = "",
        normalizedName: String = "",
        lastUsedAt: Date = Date(),
        usageCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.normalizedName = normalizedName
        self.lastUsedAt = lastUsedAt
        self.usageCount = usageCount
    }
}

@Model
final class StorageLocation {
    var id: UUID = UUID()
    var name: String = ""
    var normalizedName: String = ""
    var lastUsedAt: Date = Date()
    var usageCount: Int = 0

    init(
        id: UUID = UUID(),
        name: String = "",
        normalizedName: String = "",
        lastUsedAt: Date = Date(),
        usageCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.normalizedName = normalizedName
        self.lastUsedAt = lastUsedAt
        self.usageCount = usageCount
    }
}
