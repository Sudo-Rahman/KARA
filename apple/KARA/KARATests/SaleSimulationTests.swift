import Foundation
import Testing
@testable import KARA

@Suite("Sale simulation")
struct SaleSimulationTests {
    @Test("Prorates current value and cost by selected integer quantity")
    func proratesSelectedObjects() {
        let totals = SaleSimulationCalculator.totals(for: [
            SaleSimulationLine(
                assetID: UUID(),
                selectedQuantity: 2,
                availableQuantity: 5,
                estimatedValueEUR: 1_000,
                purchaseCostEUR: 600
            ),
            SaleSimulationLine(
                assetID: UUID(),
                selectedQuantity: 0,
                availableQuantity: 1,
                estimatedValueEUR: 9_999,
                purchaseCostEUR: 1
            ),
        ])

        #expect(totals.selectedObjectCount == 2)
        #expect(totals.estimatedProceedsEUR == 400)
        #expect(totals.purchaseCostEUR == 240)
        #expect(totals.estimatedGainEUR == 160)
        #expect((totals.gainPercentage ?? 0) > Decimal(string: "66.66")!)
        #expect((totals.gainPercentage ?? 0) < Decimal(string: "66.67")!)
    }

    @Test("Missing purchase cost keeps proceeds but makes performance unavailable")
    func handlesMissingCost() {
        let totals = SaleSimulationCalculator.totals(for: [
            SaleSimulationLine(
                assetID: UUID(),
                selectedQuantity: 1,
                availableQuantity: 1,
                estimatedValueEUR: 100,
                purchaseCostEUR: nil
            ),
        ])

        #expect(totals.estimatedProceedsEUR == 100)
        #expect(totals.purchaseCostEUR == nil)
        #expect(totals.estimatedGainEUR == nil)
        #expect(totals.gainPercentage == nil)
    }
}
