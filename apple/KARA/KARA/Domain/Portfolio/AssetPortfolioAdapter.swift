import Foundation

extension Asset {
    var portfolioSnapshot: PortfolioAssetSnapshot {
        PortfolioAssetSnapshot(
            id: id,
            name: name,
            categoryID: category.rawValue,
            metal: metal?.marketMetal,
            quantity: quantity,
            grossWeightGrams: weightGrams.flatMap(Self.decimal),
            finenessPermille: finenessPermille.flatMap(Self.decimal),
            metalKarat: metalKarat.map { Decimal($0) },
            purchaseCost: pricePaidMinorUnits.flatMap {
                MoneyConverter.decimalAmount(from: $0, currencyCode: currencyCode)
            },
            purchaseCurrency: MarketCurrency(rawValue: currencyCode),
            purchaseDate: purchaseDate
        )
    }

    private static func decimal(_ value: Double) -> Decimal? {
        Decimal(
            string: String(value),
            locale: Locale(identifier: "en_US_POSIX")
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
