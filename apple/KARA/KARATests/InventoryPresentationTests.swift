import Foundation
import Testing
@testable import KARA

@Suite("Inventory presentation")
@MainActor
struct InventoryPresentationTests {
    @Test("Search spans metadata and folds accents")
    func searchesAllUsefulMetadata() {
        let asset = Asset(
            name: "Bracelet ancien",
            category: .jewelry,
            metal: .gold,
            sellerName: "Maison Durand",
            storageLocationName: "Coffre principal",
            invoiceNumber: "FAC-2026-42",
            serialNumber: "KARA-009",
            tags: ["Héritage", "Long terme"]
        )

        #expect(InventoryQuery.matches(asset, searchText: "heritage"))
        #expect(InventoryQuery.matches(asset, searchText: "kara-009"))
        #expect(InventoryQuery.matches(asset, searchText: "coffre principal"))
        #expect(InventoryQuery.matches(asset, searchText: "or"))
        #expect(!InventoryQuery.matches(asset, searchText: "lingot"))
    }

    @Test("Filters compose metal and category")
    func composesFilters() {
        let goldCoin = Asset(name: "Coin", category: .coin, metal: .gold)

        #expect(InventoryQuery.matches(goldCoin, metal: .gold, category: .coin))
        #expect(!InventoryQuery.matches(goldCoin, metal: .silver, category: .coin))
        #expect(!InventoryQuery.matches(goldCoin, metal: .gold, category: .bar))
    }

    @Test("Value sorting keeps unknown values at the end")
    func sortsKnownValuesFirst() {
        let first = Asset(name: "First", createdAt: Date(timeIntervalSince1970: 1))
        let second = Asset(name: "Second", createdAt: Date(timeIntervalSince1970: 2))
        let missing = Asset(name: "Missing", createdAt: Date(timeIntervalSince1970: 3))
        let valuations = [
            first.id: InventoryValue(estimatedValueEUR: 50, gainPercentage: 2),
            second.id: InventoryValue(estimatedValueEUR: 100, gainPercentage: 1),
        ]

        let sorted = InventoryQuery.sorted(
            [first, missing, second],
            by: .estimatedValue,
            values: valuations
        )

        #expect(sorted.map(\.id) == [second.id, first.id, missing.id])
    }
}
