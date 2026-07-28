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

    @Test("A held-quantity snapshot prorates the acquisition cost after a partial sale")
    func mapsRemainingHoldingToMarketSnapshot() throws {
        let asset = Asset(
            name: "Four coins",
            category: .coin,
            quantity: 4,
            metal: .gold,
            weightGrams: 6.45,
            finenessPermille: 900,
            pricePaidMinorUnits: 200_000,
            currencyCode: "EUR"
        )

        let snapshot = asset.portfolioSnapshot(heldQuantity: 3)

        #expect(snapshot.quantity == 3)
        #expect(snapshot.purchaseCost == 1_500)
    }

    @Test("A sale line maps its immutable pre-sale asset version")
    func mapsSaleLineSnapshotToHistoryAsset() {
        let asset = Asset(
            name: "Two original coins",
            category: .coin,
            quantity: 2,
            purchaseDate: Date(timeIntervalSince1970: 1_700_000_000),
            metal: .gold,
            weightGrams: 6.45,
            metalKarat: 22,
            finenessPermille: 916.7,
            pricePaidMinorUnits: 120_000,
            currencyCode: "EUR"
        )
        let line = SaleLine(
            saleID: UUID(),
            asset: asset,
            quantity: 1,
            grossProceedsAmount: 700,
            saleCurrencyCode: "EUR"
        )

        asset.quantity = 8
        asset.weightGrams = 20
        asset.finenessPermille = 500

        let snapshot = line.portfolioSnapshotBeforeSale

        #expect(snapshot.id == asset.id)
        #expect(snapshot.name == "Two original coins")
        #expect(snapshot.categoryID == AssetCategory.coin.rawValue)
        #expect(snapshot.metal == .gold)
        #expect(snapshot.quantity == 2)
        #expect(snapshot.grossWeightGrams == Decimal(string: "6.45"))
        #expect(snapshot.finenessPermille == Decimal(string: "916.7"))
        #expect(snapshot.metalKarat == 22)
        #expect(snapshot.purchaseCost == 1_200)
        #expect(snapshot.purchaseCurrency == .eur)
        #expect(snapshot.purchaseDate == Date(timeIntervalSince1970: 1_700_000_000))
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
