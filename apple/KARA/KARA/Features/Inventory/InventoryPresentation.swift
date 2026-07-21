import Foundation

enum InventorySortOption: String, CaseIterable, Identifiable {
    case recent
    case estimatedValue
    case performance
    case name

    var id: String { rawValue }

    var localizationKey: String {
        "inventory.sort.\(rawValue)"
    }
}

struct InventoryValue: Equatable, Sendable {
    let estimatedValueEUR: Decimal?
    let gainPercentage: Decimal?

    init(estimatedValueEUR: Decimal? = nil, gainPercentage: Decimal? = nil) {
        self.estimatedValueEUR = estimatedValueEUR
        self.gainPercentage = gainPercentage
    }
}

enum InventoryQuery {
    static func matches(
        _ asset: Asset,
        searchText: String = "",
        metal: PreciousMetal? = nil,
        category: AssetCategory? = nil
    ) -> Bool {
        if let metal, asset.metal != metal { return false }
        if let category, asset.category != category { return false }

        let terms = normalized(searchText)
            .split(whereSeparator: \.isWhitespace)
        guard !terms.isEmpty else { return true }

        let haystack = normalized([
            asset.name,
            asset.category.rawValue,
            asset.category.searchAliases,
            asset.metal?.rawValue,
            asset.metal?.searchAliases,
            asset.presetID,
            asset.sellerName,
            asset.storageLocationName,
            asset.invoiceNumber,
            asset.serialNumber,
            asset.tags.joined(separator: " "),
        ]
        .compactMap { $0 }
        .joined(separator: " "))

        return terms.allSatisfy { haystack.contains($0) }
    }

    static func sorted(
        _ assets: [Asset],
        by option: InventorySortOption,
        values: [UUID: InventoryValue]
    ) -> [Asset] {
        assets.sorted { lhs, rhs in
            switch option {
            case .recent:
                return lhs.createdAt == rhs.createdAt
                    ? lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                    : lhs.createdAt > rhs.createdAt
            case .estimatedValue:
                return compareDescending(
                    values[lhs.id]?.estimatedValueEUR,
                    values[rhs.id]?.estimatedValueEUR,
                    lhs: lhs,
                    rhs: rhs
                )
            case .performance:
                return compareDescending(
                    values[lhs.id]?.gainPercentage,
                    values[rhs.id]?.gainPercentage,
                    lhs: lhs,
                    rhs: rhs
                )
            case .name:
                let comparison = lhs.name.localizedStandardCompare(rhs.name)
                return comparison == .orderedSame ? lhs.createdAt > rhs.createdAt : comparison == .orderedAscending
            }
        }
    }

    private static func compareDescending(
        _ lhsValue: Decimal?,
        _ rhsValue: Decimal?,
        lhs: Asset,
        rhs: Asset
    ) -> Bool {
        switch (lhsValue, rhsValue) {
        case let (lhsValue?, rhsValue?):
            return lhsValue == rhsValue ? lhs.createdAt > rhs.createdAt : lhsValue > rhsValue
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return lhs.createdAt > rhs.createdAt
        }
    }

    private static func normalized(_ value: String) -> String {
        value.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: .current
        )
    }
}

private extension AssetCategory {
    var searchAliases: String {
        switch self {
        case .bar:
            "bar bullion ingot lingot lingotin"
        case .coin:
            "coin coins piece pieces pièce pièces monnaie"
        case .jewelry:
            "jewelry jewellery jewel bijou bijoux joaillerie"
        case .custom:
            "custom other autre objet"
        }
    }
}

private extension PreciousMetal {
    var searchAliases: String {
        switch self {
        case .gold:
            "gold or"
        case .silver:
            "silver argent"
        case .platinum:
            "platinum platine"
        case .palladium:
            "palladium"
        case .other:
            "other autre"
        }
    }
}
