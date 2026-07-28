import Foundation
import SwiftData
import Testing
@testable import KARA

@Suite("Sales consistency")
@MainActor
struct SalesConsistencyTests {
    @Test("Duplicate lines for one logical sale are counted only once")
    func duplicateLogicalSaleLinesDoNotDoubleSubtractHoldings() throws {
        let container = try KaraModelContainerFactory.make(
            arguments: [KaraModelContainerFactory.inMemoryLaunchArgument],
            environment: [:]
        )
        let context = ModelContext(container)
        let repository = SalesRepository(context: context)
        let asset = Asset(
            name: "Lot de trois pièces",
            category: .coin,
            quantity: 3
        )
        let sale = Sale(grossAmount: 600)
        let first = SaleLine(
            saleID: sale.id,
            asset: asset,
            quantity: 1,
            grossProceedsAmount: 600,
            saleCurrencyCode: "EUR"
        )
        let cloudDuplicate = SaleLine(
            saleID: sale.id,
            asset: asset,
            quantity: 1,
            grossProceedsAmount: 600,
            saleCurrencyCode: "EUR"
        )

        context.insert(asset)
        context.insert(sale)
        context.insert(first)
        context.insert(cloudDuplicate)
        try context.save()

        #expect(try repository.recordedSaleLines().count == 1)
        #expect(try repository.heldQuantity(for: asset) == 2)
    }

    @Test("A line matching its authoritative sale wins over a larger corrupt duplicate")
    func authoritativeSaleFieldsResolveConflictingLineQuantity() throws {
        let container = try KaraModelContainerFactory.make(
            arguments: [KaraModelContainerFactory.inMemoryLaunchArgument],
            environment: [:]
        )
        let context = ModelContext(container)
        let repository = SalesRepository(context: context)
        let asset = Asset(
            name: "Lot de quatre lingotins",
            category: .bar,
            quantity: 4
        )
        let sale = Sale(grossAmount: 600)
        let sharedLineID = UUID()
        let matching = SaleLine(
            id: sharedLineID,
            saleID: sale.id,
            asset: asset,
            quantity: 1,
            grossProceedsAmount: 600,
            saleCurrencyCode: "EUR"
        )
        let corruptLargerDuplicate = SaleLine(
            id: sharedLineID,
            saleID: sale.id,
            asset: asset,
            quantity: 3,
            grossProceedsAmount: 999,
            saleCurrencyCode: "EUR"
        )

        context.insert(asset)
        context.insert(sale)
        context.insert(matching)
        context.insert(corruptLargerDuplicate)
        try context.save()

        let lines = try repository.recordedSaleLines()
        #expect(lines.count == 1)
        #expect(lines.first?.quantity == 1)
        #expect(try repository.heldQuantity(for: asset) == 3)
    }

    @Test("An orphaned imported line cannot affect the vault")
    func orphanedLineDoesNotAffectHoldings() throws {
        let container = try KaraModelContainerFactory.make(
            arguments: [KaraModelContainerFactory.inMemoryLaunchArgument],
            environment: [:]
        )
        let context = ModelContext(container)
        let repository = SalesRepository(context: context)
        let asset = Asset(
            name: "Deux pièces",
            category: .coin,
            quantity: 2
        )
        let orphan = SaleLine(
            saleID: UUID(),
            asset: asset,
            quantity: 2,
            grossProceedsAmount: 1_200,
            saleCurrencyCode: "EUR"
        )

        context.insert(asset)
        context.insert(orphan)
        try context.save()

        #expect(try repository.recordedSaleLines().isEmpty)
        #expect(try repository.heldQuantity(for: asset) == 2)
    }
}
