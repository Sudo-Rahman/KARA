import Foundation
import Testing
@testable import KARA

@Suite("Portfolio asset adapter")
@MainActor
struct PortfolioAssetAdapterTests {
    @Test("Maps persisted units, purchase money and supported metal")
    func mapsAssetToMarketSnapshot() throws {
        let asset = Asset(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!,
            name: "Silver bar",
            category: .bar,
            quantity: 3,
            purchaseDate: Date(timeIntervalSince1970: 1_700_000_000),
            metal: .silver,
            weightGrams: 100,
            metalKarat: nil,
            finenessPermille: 999,
            pricePaidMinorUnits: 12_345,
            currencyCode: "USD"
        )

        let snapshot = asset.portfolioSnapshot

        #expect(snapshot.id == asset.id)
        #expect(snapshot.categoryID == AssetCategory.bar.rawValue)
        #expect(snapshot.metal == .silver)
        #expect(snapshot.quantity == 3)
        #expect(snapshot.grossWeightGrams == 100)
        #expect(snapshot.finenessPermille == 999)
        #expect(snapshot.purchaseCost == Decimal(string: "123.45"))
        #expect(snapshot.purchaseCurrency == .usd)
        #expect(snapshot.purchaseDate == asset.purchaseDate)
    }

    @Test("Requests EUR valuation and original purchase currency quotes")
    func derivesRequiredSpotPairs() {
        let gold = Asset(
            name: "Gold",
            category: .coin,
            metal: .gold,
            weightGrams: 10,
            finenessPermille: 999,
            pricePaidMinorUnits: 10_000,
            currencyCode: "CHF"
        )
        let unsupported = Asset(
            name: "Other",
            category: .custom,
            metal: .other,
            weightGrams: 10,
            finenessPermille: 999,
            currencyCode: "EUR"
        )

        let pairs = requiredSpotPairs(for: [gold, unsupported])

        #expect(pairs.contains(SpotPair(metal: .gold, currency: .eur)))
        #expect(pairs.contains(SpotPair(metal: .gold, currency: .chf)))
        #expect(pairs.contains(SpotPair(metal: .gold, currency: .eur)))
        #expect(!pairs.contains(SpotPair(metal: .silver, currency: .eur)))
    }
}
