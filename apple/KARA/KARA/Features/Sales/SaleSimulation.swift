import Foundation

nonisolated struct SaleSimulationLine: Equatable, Sendable {
    let assetID: UUID
    let selectedQuantity: Int
    let availableQuantity: Int
    let estimatedValueEUR: Decimal
    let purchaseCostEUR: Decimal?

    init(
        assetID: UUID,
        selectedQuantity: Int,
        availableQuantity: Int,
        estimatedValueEUR: Decimal,
        purchaseCostEUR: Decimal?
    ) {
        self.assetID = assetID
        self.selectedQuantity = selectedQuantity
        self.availableQuantity = availableQuantity
        self.estimatedValueEUR = estimatedValueEUR
        self.purchaseCostEUR = purchaseCostEUR
    }
}

nonisolated struct SaleSimulationTotals: Equatable, Sendable {
    let selectedObjectCount: Int
    let estimatedProceedsEUR: Decimal
    let purchaseCostEUR: Decimal?
    let estimatedGainEUR: Decimal?
    let gainPercentage: Decimal?
}

nonisolated enum SaleSimulationCalculator {
    static func totals(for lines: [SaleSimulationLine]) -> SaleSimulationTotals {
        let selectedLines = lines.compactMap { line -> ProratedLine? in
            guard line.availableQuantity > 0 else { return nil }
            let selectedQuantity = min(max(0, line.selectedQuantity), line.availableQuantity)
            guard selectedQuantity > 0 else { return nil }

            let share = Decimal(selectedQuantity) / Decimal(line.availableQuantity)
            return ProratedLine(
                selectedQuantity: selectedQuantity,
                estimatedProceedsEUR: line.estimatedValueEUR * share,
                purchaseCostEUR: line.purchaseCostEUR.map { $0 * share }
            )
        }

        let proceeds = selectedLines.reduce(Decimal.zero) { $0 + $1.estimatedProceedsEUR }
        let hasCompleteCosts = selectedLines.allSatisfy { $0.purchaseCostEUR != nil }
        let cost = selectedLines.isEmpty || !hasCompleteCosts
            ? nil
            : selectedLines.compactMap(\.purchaseCostEUR).reduce(Decimal.zero, +)
        let gain = cost.map { proceeds - $0 }
        let percentage: Decimal?
        if let cost, cost != 0, let gain {
            percentage = gain / cost * 100
        } else {
            percentage = nil
        }

        return SaleSimulationTotals(
            selectedObjectCount: selectedLines.reduce(0) { $0 + $1.selectedQuantity },
            estimatedProceedsEUR: proceeds,
            purchaseCostEUR: cost,
            estimatedGainEUR: gain,
            gainPercentage: percentage
        )
    }
}

private nonisolated struct ProratedLine {
    let selectedQuantity: Int
    let estimatedProceedsEUR: Decimal
    let purchaseCostEUR: Decimal?
}
