import Foundation
import SwiftData

nonisolated struct SaleAlertStateSnapshot: Codable, Equatable, Sendable {
    let alertID: UUID
    let previousStatus: PriceAlertStatus
    let appliedStatus: PriceAlertStatus
}

@Model
final class SaleLine {
    var id: UUID = UUID()
    var saleID: UUID = UUID()
    var assetID: UUID = UUID()
    var quantity: Int = 0
    var assetQuantitySnapshot: Int = 1
    var grossProceedsMinorUnits: Int64 = 0
    var saleCurrencyCode: String = "EUR"
    var assetNameSnapshot: String = ""
    var presetIDSnapshot: String?
    var categoryRawValueSnapshot: String = AssetCategory.custom.rawValue
    var purchaseDateSnapshot: Date?
    var metalRawValueSnapshot: String?
    var weightGramsSnapshot: Decimal?
    var metalKaratSnapshot: Int?
    var finenessPermilleSnapshot: Decimal?
    var gemstoneCaratWeightSnapshot: Decimal?
    var gemstoneClaritySnapshot: String?
    var purchaseCostMinorUnitsSnapshot: Int64?
    var allocatedPurchaseCostMinorUnitsSnapshot: Int64?
    var purchaseCurrencyCodeSnapshot: String = "EUR"
    var sellerNameSnapshot: String?
    var storageLocationNameSnapshot: String?
    var invoiceNumberSnapshot: String?
    var serialNumberSnapshot: String?
    var acquisitionMethodRawValueSnapshot: String?
    var tagsJSONSnapshot: String = "[]"
    var alertStateSnapshotsJSON: String = "[]"
    var spotValueAtSaleMinorUnits: Int64?
    var voidedAt: Date?

    var isActive: Bool {
        voidedAt == nil
    }

    var grossProceedsAmount: Decimal {
        MoneyConverter.decimalAmount(
            from: grossProceedsMinorUnits,
            currencyCode: saleCurrencyCode
        ) ?? 0
    }

    var purchaseCostAmountSnapshot: Decimal? {
        purchaseCostMinorUnitsSnapshot.flatMap {
            MoneyConverter.decimalAmount(
                from: $0,
                currencyCode: purchaseCurrencyCodeSnapshot
            )
        }
    }

    var allocatedPurchaseCostAmountSnapshot: Decimal? {
        allocatedPurchaseCostMinorUnitsSnapshot.flatMap {
            MoneyConverter.decimalAmount(
                from: $0,
                currencyCode: purchaseCurrencyCodeSnapshot
            )
        }
    }

    var spotValueAtSale: Decimal? {
        spotValueAtSaleMinorUnits.flatMap {
            MoneyConverter.decimalAmount(
                from: $0,
                currencyCode: saleCurrencyCode
            )
        }
    }

    var categorySnapshot: AssetCategory {
        AssetCategory(rawValue: categoryRawValueSnapshot) ?? .custom
    }

    var metalSnapshot: PreciousMetal? {
        metalRawValueSnapshot.flatMap(PreciousMetal.init(rawValue:))
    }

    var acquisitionMethodSnapshot: AssetAcquisitionMethod? {
        acquisitionMethodRawValueSnapshot.flatMap(
            AssetAcquisitionMethod.init(rawValue:)
        )
    }

    var alertStateSnapshots: [SaleAlertStateSnapshot] {
        get {
            guard let data = alertStateSnapshotsJSON.data(using: .utf8),
                  let snapshots = try? JSONDecoder().decode(
                      [SaleAlertStateSnapshot].self,
                      from: data
                  )
            else {
                return []
            }
            return snapshots
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let encoded = String(data: data, encoding: .utf8)
            else {
                alertStateSnapshotsJSON = "[]"
                return
            }
            alertStateSnapshotsJSON = encoded
        }
    }

    init(
        id: UUID = UUID(),
        saleID: UUID,
        asset: Asset,
        quantity: Int,
        grossProceedsAmount: Decimal,
        saleCurrencyCode: String,
        spotValueAtSale: Decimal? = nil
    ) {
        self.id = id
        self.saleID = saleID
        assetID = asset.id
        self.quantity = quantity
        assetQuantitySnapshot = asset.quantity
        self.saleCurrencyCode = saleCurrencyCode
        grossProceedsMinorUnits = MoneyConverter.minorUnits(
            from: grossProceedsAmount,
            currencyCode: saleCurrencyCode
        ) ?? 0
        assetNameSnapshot = asset.name
        presetIDSnapshot = asset.presetID
        categoryRawValueSnapshot = asset.categoryRawValue
        purchaseDateSnapshot = asset.purchaseDate
        metalRawValueSnapshot = asset.metalRawValue
        weightGramsSnapshot = asset.weightGrams.flatMap(Self.decimal)
        metalKaratSnapshot = asset.metalKarat
        finenessPermilleSnapshot = asset.finenessPermille.flatMap(Self.decimal)
        gemstoneCaratWeightSnapshot = asset.gemstoneCaratWeight.flatMap(
            Self.decimal
        )
        gemstoneClaritySnapshot = asset.gemstoneClarity
        purchaseCostMinorUnitsSnapshot = asset.pricePaidMinorUnits
        purchaseCurrencyCodeSnapshot = asset.currencyCode
        if let totalPurchaseCostMinorUnits = asset.pricePaidMinorUnits,
           asset.quantity > 0,
           let totalPurchaseCost = MoneyConverter.decimalAmount(
               from: totalPurchaseCostMinorUnits,
               currencyCode: asset.currencyCode
           ) {
            allocatedPurchaseCostMinorUnitsSnapshot =
                MoneyConverter.minorUnits(
                    from: totalPurchaseCost
                        * Decimal(quantity)
                        / Decimal(asset.quantity),
                    currencyCode: asset.currencyCode
                )
        }
        sellerNameSnapshot = asset.sellerName
        storageLocationNameSnapshot = asset.storageLocationName
        invoiceNumberSnapshot = asset.invoiceNumber
        serialNumberSnapshot = asset.serialNumber
        acquisitionMethodRawValueSnapshot = asset.acquisitionMethodRawValue
        tagsJSONSnapshot = asset.tagsJSON
        spotValueAtSaleMinorUnits = spotValueAtSale.flatMap {
            MoneyConverter.minorUnits(
                from: $0,
                currencyCode: saleCurrencyCode
            )
        }
    }

    private static func decimal(_ value: Double) -> Decimal? {
        Decimal(
            string: String(value),
            locale: Locale(identifier: "en_US_POSIX")
        )
    }
}
