import Foundation

nonisolated struct PortfolioAnalyticsBreakdownItem: Equatable, Identifiable, Sendable {
    let key: String
    let valueEUR: Decimal
    let sharePercentage: Decimal?
    let recordCount: Int

    var id: String { key }
}

nonisolated struct PortfolioAnalyticsBreakdownCoverage: Equatable, Sendable {
    let totalRecordCount: Int
    let includedRecordCount: Int
    let totalKnownValueEUR: Decimal
    let representedValueEUR: Decimal

    var recordPercentage: Decimal? {
        percentage(
            part: Decimal(includedRecordCount),
            whole: Decimal(totalRecordCount)
        )
    }

    var valuePercentage: Decimal? {
        percentage(part: representedValueEUR, whole: totalKnownValueEUR)
    }

    var isComplete: Bool {
        totalRecordCount == includedRecordCount
            && (totalKnownValueEUR == 0 || totalKnownValueEUR == representedValueEUR)
    }

    private func percentage(part: Decimal, whole: Decimal) -> Decimal? {
        guard whole > 0 else { return nil }
        return part / whole * 100
    }
}

nonisolated struct PortfolioAnalyticsBreakdown: Equatable, Sendable {
    let items: [PortfolioAnalyticsBreakdownItem]
    let coverage: PortfolioAnalyticsBreakdownCoverage
}

nonisolated enum PortfolioAnalyticsBreakdownBuilder {
    static func build(
        from valuations: [AssetValuation],
        key: (AssetValuation) -> String?
    ) -> PortfolioAnalyticsBreakdown {
        let knownValues = valuations.compactMap(\.estimatedValueEUR)
        let totalKnownValue = knownValues.reduce(0, +)
        let included = valuations.compactMap { valuation -> IncludedValue? in
            guard let value = valuation.estimatedValueEUR,
                  let rawKey = key(valuation),
                  let cleanKey = nonBlank(rawKey)
            else {
                return nil
            }
            return IncludedValue(key: cleanKey, valueEUR: value)
        }
        let grouped = Dictionary(grouping: included, by: \.key)
        let items = grouped.map { key, values in
            let value = values.map(\.valueEUR).reduce(0, +)
            return PortfolioAnalyticsBreakdownItem(
                key: key,
                valueEUR: value,
                sharePercentage: totalKnownValue > 0
                    ? value / totalKnownValue * 100
                    : nil,
                recordCount: values.count
            )
        }
        .sorted { lhs, rhs in
            if lhs.valueEUR == rhs.valueEUR {
                return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
            }
            return lhs.valueEUR > rhs.valueEUR
        }

        return PortfolioAnalyticsBreakdown(
            items: items,
            coverage: PortfolioAnalyticsBreakdownCoverage(
                totalRecordCount: valuations.count,
                includedRecordCount: included.count,
                totalKnownValueEUR: totalKnownValue,
                representedValueEUR: included.map(\.valueEUR).reduce(0, +)
            )
        )
    }

    private static func nonBlank(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private struct IncludedValue {
        let key: String
        let valueEUR: Decimal
    }
}
