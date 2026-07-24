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

    @Test("Asset history is hidden until three calendar months have elapsed")
    func hidesRecentAssetHistory() {
        let calendar = utcCalendar
        let asOf = date(year: 2026, month: 7, day: 24)

        #expect(!AssetDetailPresentation.showsHistory(
            purchaseDate: date(year: 2026, month: 4, day: 25),
            asOf: asOf,
            calendar: calendar
        ))
        #expect(AssetDetailPresentation.showsHistory(
            purchaseDate: date(year: 2026, month: 4, day: 24),
            asOf: asOf,
            calendar: calendar
        ))
        #expect(AssetDetailPresentation.showsHistory(
            purchaseDate: date(year: 2026, month: 4, day: 23),
            asOf: asOf,
            calendar: calendar
        ))
    }

    @Test("An unknown purchase date keeps asset history eligible")
    func keepsUnknownDateHistoryEligible() {
        #expect(AssetDetailPresentation.showsHistory(
            purchaseDate: nil,
            asOf: date(year: 2026, month: 7, day: 24),
            calendar: utcCalendar
        ))
    }

    @Test("Completeness guidance disappears at one hundred percent")
    func hidesCompleteAssetGuidance() {
        #expect(AssetDetailPresentation.showsCompleteness(0.99))
        #expect(!AssetDetailPresentation.showsCompleteness(1))
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
