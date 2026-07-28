import Foundation

nonisolated enum SaleDisposition: Equatable, Sendable {
    case partial
    case full
}

nonisolated enum SaleRecordingError: Error, Equatable {
    case invalidQuantity
    case quantityExceedsHeld(heldQuantity: Int)
    case salePredatesPurchase
    case invalidGrossAmount
    case invalidFeesAmount
    case invalidCurrency
    case invalidSpotValue
}

struct RecordedSale {
    let sale: Sale
    let line: SaleLine
    let disposition: SaleDisposition
}

enum SalesLedger {
    static func heldQuantity(
        for asset: Asset,
        saleLines: [SaleLine]
    ) -> Int {
        heldQuantity(
            for: asset,
            recordedSaleLines: saleLines.filter(\.isActive)
        )
    }

    static func heldQuantity(
        for asset: Asset,
        recordedSaleLines: [SaleLine]
    ) -> Int {
        let soldQuantity = recordedSaleLines.reduce(into: 0) { total, line in
            guard line.assetID == asset.id else { return }
            total += max(0, line.quantity)
        }
        return max(0, asset.quantity - soldQuantity)
    }

    static func isFullySold(
        _ asset: Asset,
        saleLines: [SaleLine]
    ) -> Bool {
        heldQuantity(for: asset, saleLines: saleLines) == 0
    }

    static func record(
        asset: Asset,
        quantity: Int,
        grossAmount: Decimal,
        feesAmount: Decimal = 0,
        currencyCode: String = "EUR",
        soldAt: Date = Date(),
        buyerName: String? = nil,
        note: String? = nil,
        spotValueAtSale: Decimal? = nil,
        existingSaleLines: [SaleLine],
        existingRecordedSaleLines: [SaleLine]? = nil,
        alerts: [PriceAlert],
        createdAt: Date = Date()
    ) throws -> RecordedSale {
        guard quantity > 0 else {
            throw SaleRecordingError.invalidQuantity
        }

        if let purchaseDate = asset.purchaseDate,
           Calendar.current.compare(
               soldAt,
               to: purchaseDate,
               toGranularity: .day
           ) == .orderedAscending {
            throw SaleRecordingError.salePredatesPurchase
        }

        let recordedSaleLines = existingRecordedSaleLines
            ?? existingSaleLines.filter(\.isActive)
        let currentlyHeld = heldQuantity(
            for: asset,
            recordedSaleLines: recordedSaleLines
        )
        guard quantity <= currentlyHeld else {
            throw SaleRecordingError.quantityExceedsHeld(
                heldQuantity: currentlyHeld
            )
        }

        let normalizedCurrencyCode = currencyCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased(with: Locale(identifier: "en_US_POSIX"))
        guard MoneyConverter.isSupportedCurrencyCode(normalizedCurrencyCode)
        else {
            throw SaleRecordingError.invalidCurrency
        }
        guard grossAmount > 0,
              let grossAmountMinorUnits = MoneyConverter.minorUnits(
                  from: grossAmount,
                  currencyCode: normalizedCurrencyCode
              ),
              grossAmountMinorUnits > 0
        else {
            throw SaleRecordingError.invalidGrossAmount
        }
        guard feesAmount >= 0,
              feesAmount <= grossAmount,
              MoneyConverter.minorUnits(
                  from: feesAmount,
                  currencyCode: normalizedCurrencyCode
              ) != nil
        else {
            throw SaleRecordingError.invalidFeesAmount
        }
        if let spotValueAtSale,
           spotValueAtSale < 0
               || MoneyConverter.minorUnits(
                   from: spotValueAtSale,
                   currencyCode: normalizedCurrencyCode
               ) == nil {
            throw SaleRecordingError.invalidSpotValue
        }

        let sale = Sale(
            soldAt: soldAt,
            grossAmount: grossAmount,
            feesAmount: feesAmount,
            currencyCode: normalizedCurrencyCode,
            buyerName: buyerName,
            note: note,
            createdAt: createdAt
        )
        let line = SaleLine(
            saleID: sale.id,
            asset: asset,
            quantity: quantity,
            grossProceedsAmount: grossAmount,
            saleCurrencyCode: normalizedCurrencyCode,
            spotValueAtSale: spotValueAtSale
        )
        let disposition: SaleDisposition =
            quantity == currentlyHeld ? .full : .partial
        let appliedAlertStatus: PriceAlertStatus =
            disposition == .full ? .completed : .needsReview
        line.alertStateSnapshots = alerts.compactMap { alert in
            guard alert.assetID == asset.id,
                  alert.status.isAdjustedBySale
            else {
                return nil
            }
            return SaleAlertStateSnapshot(
                alertID: alert.id,
                previousStatus: alert.status,
                appliedStatus: appliedAlertStatus
            )
        }
        if disposition == .full,
           let totalPurchaseCost = line.purchaseCostMinorUnitsSnapshot {
            let alreadyAllocated = recordedSaleLines.reduce(into: Int64(0)) {
                total, existingLine in
                guard existingLine.assetID == asset.id,
                      existingLine.purchaseCurrencyCodeSnapshot
                          == line.purchaseCurrencyCodeSnapshot,
                      let allocated =
                          existingLine.allocatedPurchaseCostMinorUnitsSnapshot
                else {
                    return
                }
                total += allocated
            }
            line.allocatedPurchaseCostMinorUnitsSnapshot = max(
                0,
                totalPurchaseCost - alreadyAllocated
            )
        }

        for alert in alerts where alert.assetID == asset.id {
            switch disposition {
            case .partial:
                alert.markNeedsReview(at: createdAt)
            case .full:
                alert.completeDueToSale(at: createdAt)
            }
        }

        return RecordedSale(
            sale: sale,
            line: line,
            disposition: disposition
        )
    }
}

private extension PriceAlertStatus {
    var isAdjustedBySale: Bool {
        switch self {
        case .active, .paused, .needsReview:
            true
        case .triggered, .completed, .cancelled:
            false
        }
    }
}
