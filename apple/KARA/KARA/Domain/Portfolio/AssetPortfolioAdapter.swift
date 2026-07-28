import Foundation

extension Asset {
    var portfolioSnapshot: PortfolioAssetSnapshot {
        portfolioSnapshot(heldQuantity: quantity)
    }

    func portfolioSnapshot(heldQuantity: Int) -> PortfolioAssetSnapshot {
        let quantity = min(max(0, heldQuantity), max(0, self.quantity))
        return PortfolioAssetSnapshot(
            id: id,
            name: name,
            categoryID: category.rawValue,
            metal: metal?.marketMetal,
            quantity: quantity,
            grossWeightGrams: weightGrams.flatMap(Self.decimal),
            finenessPermille: finenessPermille.flatMap(Self.decimal),
            metalKarat: metalKarat.map { Decimal($0) },
            purchaseCost: proratedPurchaseCost(forHeldQuantity: quantity),
            purchaseCurrency: MarketCurrency(rawValue: currencyCode),
            purchaseDate: purchaseDate
        )
    }

    private func proratedPurchaseCost(forHeldQuantity heldQuantity: Int) -> Decimal? {
        guard quantity > 0,
              heldQuantity >= 0,
              let pricePaidMinorUnits,
              let originalCost = MoneyConverter.decimalAmount(
                  from: pricePaidMinorUnits,
                  currencyCode: currencyCode
              )
        else {
            return nil
        }

        return originalCost * Decimal(heldQuantity) / Decimal(quantity)
    }

    private static func decimal(_ value: Double) -> Decimal? {
        Decimal(
            string: String(value),
            locale: Locale(identifier: "en_US_POSIX")
        )
    }
}

extension SaleLine {
    var portfolioSnapshotBeforeSale: PortfolioAssetSnapshot {
        PortfolioAssetSnapshot(
            id: assetID,
            name: assetNameSnapshot,
            categoryID: categoryRawValueSnapshot,
            metal: metalSnapshot?.marketMetal,
            quantity: max(0, assetQuantitySnapshot),
            grossWeightGrams: weightGramsSnapshot,
            finenessPermille: finenessPermilleSnapshot,
            metalKarat: metalKaratSnapshot.map { Decimal($0) },
            purchaseCost: purchaseCostAmountSnapshot,
            purchaseCurrency: MarketCurrency(
                rawValue: purchaseCurrencyCodeSnapshot
            ),
            purchaseDate: purchaseDateSnapshot
        )
    }
}

extension PreciousMetal {
    var marketMetal: MarketMetal? {
        switch self {
        case .gold:
            .gold
        case .silver:
            .silver
        case .platinum:
            .platinum
        case .palladium:
            .palladium
        case .other:
            nil
        }
    }
}

extension MarketMetal {
    var preciousMetal: PreciousMetal {
        switch self {
        case .gold:
            .gold
        case .silver:
            .silver
        case .platinum:
            .platinum
        case .palladium:
            .palladium
        }
    }
}

func requiredSpotPairs(for assets: [Asset]) -> Set<SpotPair> {
    var pairs: Set<SpotPair> = [SpotPair(metal: .gold, currency: .eur)]

    for asset in assets {
        guard let metal = asset.metal?.marketMetal else { continue }
        pairs.insert(SpotPair(metal: metal, currency: .eur))

        if let currency = MarketCurrency(rawValue: asset.currencyCode) {
            pairs.insert(SpotPair(metal: metal, currency: currency))
        }
    }

    return pairs
}
