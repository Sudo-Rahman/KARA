import Foundation
import SwiftData
import Testing
@testable import KARA

@Suite("Sales domain")
@MainActor
struct SalesDomainTests {
    @Test("A sale line keeps an immutable monetary snapshot of the sold asset")
    func saleLineSnapshotsTheAsset() throws {
        let asset = Asset(
            name: "Napoléon 20 Francs",
            category: .coin,
            presetID: "napoleon-20-francs",
            quantity: 3,
            purchaseDate: Date(timeIntervalSince1970: 1_700_000_000),
            metal: .gold,
            weightGrams: 6.45,
            metalKarat: 22,
            finenessPermille: 900,
            pricePaidMinorUnits: 32_500,
            currencyCode: "EUR",
            sellerName: "Maison Or",
            storageLocationName: "Coffre banque",
            invoiceNumber: "FAC-42",
            serialNumber: "NP-001",
            acquisitionMethod: .purchase,
            tags: ["collection"]
        )
        let saleID = UUID()

        let line = SaleLine(
            saleID: saleID,
            asset: asset,
            quantity: 2,
            grossProceedsAmount: Decimal(string: "525.75")!,
            saleCurrencyCode: "EUR",
            spotValueAtSale: Decimal(string: "490.25")!
        )

        asset.name = "Nom modifié après la vente"
        asset.weightGrams = 99

        #expect(line.saleID == saleID)
        #expect(line.assetID == asset.id)
        #expect(line.quantity == 2)
        #expect(line.assetQuantitySnapshot == 3)
        #expect(line.grossProceedsAmount == Decimal(string: "525.75"))
        #expect(line.grossProceedsMinorUnits == 52_575)
        #expect(line.assetNameSnapshot == "Napoléon 20 Francs")
        #expect(line.presetIDSnapshot == "napoleon-20-francs")
        #expect(line.categorySnapshot == .coin)
        #expect(line.metalSnapshot == .gold)
        #expect(line.weightGramsSnapshot == Decimal(string: "6.45"))
        #expect(line.metalKaratSnapshot == 22)
        #expect(line.finenessPermilleSnapshot == Decimal(900))
        #expect(line.purchaseCostAmountSnapshot == Decimal(string: "325"))
        #expect(
            line.allocatedPurchaseCostAmountSnapshot
                == Decimal(string: "216.67")
        )
        #expect(line.purchaseCurrencyCodeSnapshot == "EUR")
        #expect(line.sellerNameSnapshot == "Maison Or")
        #expect(line.storageLocationNameSnapshot == "Coffre banque")
        #expect(line.invoiceNumberSnapshot == "FAC-42")
        #expect(line.serialNumberSnapshot == "NP-001")
        #expect(line.acquisitionMethodSnapshot == .purchase)
        #expect(line.spotValueAtSale == Decimal(string: "490.25"))
        #expect(line.spotValueAtSaleMinorUnits == 49_025)
    }

    @Test("A sale stores decimal amounts and exposes the net amount received")
    func saleCalculatesNetAmount() {
        let soldAt = Date(timeIntervalSince1970: 1_720_000_000)
        let sale = Sale(
            soldAt: soldAt,
            grossAmount: Decimal(string: "3000.55")!,
            feesAmount: Decimal(string: "25.35")!,
            currencyCode: "eur",
            buyerName: "Comptoir local",
            note: "Paiement reçu"
        )

        #expect(sale.soldAt == soldAt)
        #expect(sale.grossAmount == Decimal(string: "3000.55"))
        #expect(sale.feesAmount == Decimal(string: "25.35"))
        #expect(sale.netAmount == Decimal(string: "2975.20"))
        #expect(sale.currencyCode == "EUR")
        #expect(sale.buyerName == "Comptoir local")
        #expect(sale.note == "Paiement reçu")
        #expect(sale.status == .recorded)
    }

    @Test("Voiding a sale restores its quantity without deleting its history")
    func voidingSaleRestoresHeldQuantity() {
        let asset = Asset(name: "Lot de pièces", category: .coin, quantity: 5)
        let sale = Sale(grossAmount: 500)
        let otherSale = Sale(grossAmount: 250)
        let line = SaleLine(
            saleID: sale.id,
            asset: asset,
            quantity: 2,
            grossProceedsAmount: 500,
            saleCurrencyCode: "EUR"
        )
        let otherLine = SaleLine(
            saleID: otherSale.id,
            asset: asset,
            quantity: 1,
            grossProceedsAmount: 250,
            saleCurrencyCode: "EUR"
        )

        #expect(
            SalesLedger.heldQuantity(
                for: asset,
                saleLines: [line, otherLine]
            ) == 2
        )

        let voidedAt = Date(timeIntervalSince1970: 1_730_000_000)
        sale.void(lines: [line, otherLine], at: voidedAt)

        #expect(sale.status == .voided)
        #expect(sale.voidedAt == voidedAt)
        #expect(line.voidedAt == voidedAt)
        #expect(otherLine.voidedAt == nil)
        #expect(
            SalesLedger.heldQuantity(
                for: asset,
                saleLines: [line, otherLine]
            ) == 4
        )
    }

    @Test("An asset can have independent alerts above and below its current value")
    func createsMultipleDirectionalAlerts() throws {
        let assetID = UUID()

        let upperAlert = try PriceAlert.make(
            assetID: assetID,
            targetValue: 3_000,
            currentValue: 2_800,
            currencyCode: "EUR"
        )
        let lowerAlert = try PriceAlert.make(
            assetID: assetID,
            targetValue: 2_000,
            currentValue: 2_800,
            currencyCode: "EUR"
        )

        #expect(upperAlert.assetID == assetID)
        #expect(lowerAlert.assetID == assetID)
        #expect(upperAlert.id != lowerAlert.id)
        #expect(upperAlert.direction == .above)
        #expect(lowerAlert.direction == .below)
        #expect(upperAlert.targetValue == 3_000)
        #expect(lowerAlert.targetValue == 2_000)
        #expect(upperAlert.status == .active)
        #expect(lowerAlert.status == .active)
    }

    @Test("An active alert triggers once when its threshold is reached")
    func evaluatesAlertThreshold() throws {
        let alert = try PriceAlert.make(
            assetID: UUID(),
            targetValue: 3_000,
            currentValue: 2_800,
            currencyCode: "EUR"
        )
        let firstCheck = Date(timeIntervalSince1970: 1_740_000_000)
        let triggerCheck = Date(timeIntervalSince1970: 1_740_000_100)

        #expect(!alert.evaluate(currentValue: 2_999, at: firstCheck))
        #expect(alert.status == .active)
        #expect(alert.lastObservedValue == 2_999)
        #expect(alert.lastCheckedAt == firstCheck)

        #expect(alert.evaluate(currentValue: 3_000, at: triggerCheck))
        #expect(alert.status == .triggered)
        #expect(alert.triggeredAt == triggerCheck)
        #expect(!alert.evaluate(currentValue: 3_100, at: triggerCheck.addingTimeInterval(1)))
    }

    @Test("Partial sales flag alerts for review and a full sale completes them")
    func saleRecordingUpdatesHeldQuantityAndAlerts() throws {
        let asset = Asset(
            name: "Lot de 3 lingotins",
            category: .bar,
            quantity: 3,
            pricePaidMinorUnits: 100,
            currencyCode: "EUR"
        )
        let upperAlert = try PriceAlert.make(
            assetID: asset.id,
            targetValue: 3_000,
            currentValue: 2_800,
            currencyCode: "EUR"
        )
        let lowerAlert = try PriceAlert.make(
            assetID: asset.id,
            targetValue: 2_000,
            currentValue: 2_800,
            currencyCode: "EUR"
        )

        let partial = try SalesLedger.record(
            asset: asset,
            quantity: 1,
            grossAmount: 900,
            currencyCode: "EUR",
            existingSaleLines: [],
            alerts: [upperAlert, lowerAlert]
        )

        #expect(partial.disposition == .partial)
        #expect(partial.line.quantity == 1)
        #expect(partial.line.allocatedPurchaseCostAmountSnapshot == Decimal(string: "0.33"))
        #expect(upperAlert.status == .needsReview)
        #expect(lowerAlert.status == .needsReview)
        #expect(
            SalesLedger.heldQuantity(
                for: asset,
                saleLines: [partial.line]
            ) == 2
        )

        let full = try SalesLedger.record(
            asset: asset,
            quantity: 2,
            grossAmount: 1_800,
            currencyCode: "EUR",
            existingSaleLines: [partial.line],
            alerts: [upperAlert, lowerAlert]
        )

        #expect(full.disposition == .full)
        #expect(full.line.allocatedPurchaseCostAmountSnapshot == Decimal(string: "0.67"))
        #expect(upperAlert.status == .completed)
        #expect(lowerAlert.status == .completed)
        #expect(
            SalesLedger.heldQuantity(
                for: asset,
                saleLines: [partial.line, full.line]
            ) == 0
        )
    }

    @Test("Sales and alerts round-trip through the app SwiftData schema")
    func persistsSalesModels() throws {
        let container = try KaraModelContainerFactory.make(
            arguments: [KaraModelContainerFactory.inMemoryLaunchArgument],
            environment: [:]
        )
        let context = ModelContext(container)
        let asset = Asset(name: "Lingot 50 g", category: .bar)
        let alert = try PriceAlert.make(
            assetID: asset.id,
            targetValue: 4_000,
            currentValue: 3_500,
            currencyCode: "EUR"
        )
        let recorded = try SalesLedger.record(
            asset: asset,
            quantity: 1,
            grossAmount: Decimal(string: "3800.50")!,
            feesAmount: Decimal(string: "10.25")!,
            currencyCode: "EUR",
            existingSaleLines: [],
            alerts: [alert]
        )

        context.insert(asset)
        context.insert(recorded.sale)
        context.insert(recorded.line)
        context.insert(alert)
        try context.save()

        let sales = try context.fetch(FetchDescriptor<Sale>())
        let lines = try context.fetch(FetchDescriptor<SaleLine>())
        let alerts = try context.fetch(FetchDescriptor<PriceAlert>())

        #expect(sales.count == 1)
        #expect(sales.first?.netAmount == Decimal(string: "3790.25"))
        #expect(lines.count == 1)
        #expect(lines.first?.assetNameSnapshot == "Lingot 50 g")
        #expect(alerts.count == 1)
        #expect(alerts.first?.status == .completed)
    }

    @Test("The repository records and voids a sale as one persisted operation")
    func repositoryRecordsAndVoidsSale() throws {
        let container = try KaraModelContainerFactory.make(
            arguments: [KaraModelContainerFactory.inMemoryLaunchArgument],
            environment: [:]
        )
        let context = ModelContext(container)
        let repository = SalesRepository(context: context)
        let asset = Asset(name: "Deux pièces", category: .coin, quantity: 2)
        context.insert(asset)
        try context.save()
        _ = try repository.createAlert(
            assetID: asset.id,
            targetValue: 700,
            currentValue: 600,
            currencyCode: "EUR"
        )

        let recorded = try repository.recordSale(
            asset: asset,
            quantity: 1,
            grossAmount: 650,
            feesAmount: 5,
            currencyCode: "EUR"
        )

        #expect(try repository.heldQuantity(for: asset) == 1)
        #expect(try repository.sales().map(\.id) == [recorded.sale.id])
        #expect(try repository.alerts().first?.status == .needsReview)

        try repository.voidSale(recorded.sale)

        #expect(try repository.heldQuantity(for: asset) == 2)
        #expect(try repository.sales(includeVoided: true).first?.status == .voided)
        #expect(try repository.sales().isEmpty)
        #expect(try repository.alerts().first?.status == .active)
    }

    @Test("Voiding a full sale restores each alert to its pre-sale state")
    func voidingFullSaleRestoresAlertState() throws {
        let container = try KaraModelContainerFactory.make(
            arguments: [KaraModelContainerFactory.inMemoryLaunchArgument],
            environment: [:]
        )
        let context = ModelContext(container)
        let repository = SalesRepository(context: context)
        let asset = Asset(name: "Pièce unique", category: .coin)
        context.insert(asset)
        let alert = try repository.createAlert(
            assetID: asset.id,
            targetValue: 700,
            currentValue: 600,
            currencyCode: "EUR"
        )
        alert.pause()
        try context.save()

        let recorded = try repository.recordSale(
            asset: asset,
            quantity: 1,
            grossAmount: 650
        )
        #expect(alert.status == .completed)

        try repository.voidSale(recorded.sale)

        #expect(alert.status == .paused)
    }

    @Test("Voiding an already voided sale is an idempotent no-op")
    func voidingSaleTwiceIsANoOp() throws {
        let container = try KaraModelContainerFactory.make(
            arguments: [KaraModelContainerFactory.inMemoryLaunchArgument],
            environment: [:]
        )
        let context = ModelContext(container)
        let repository = SalesRepository(context: context)
        let asset = Asset(name: "Pièce unique", category: .coin)
        context.insert(asset)
        let alert = try repository.createAlert(
            assetID: asset.id,
            targetValue: 700,
            currentValue: 600,
            currencyCode: "EUR"
        )
        let recorded = try repository.recordSale(
            asset: asset,
            quantity: 1,
            grossAmount: 650
        )
        let firstVoidDate = Date(timeIntervalSince1970: 1_750_000_000)
        try repository.voidSale(recorded.sale, at: firstVoidDate)

        alert.pause(at: firstVoidDate.addingTimeInterval(1))
        let alertUpdateAfterUserAction = alert.updatedAt
        try repository.voidSale(
            recorded.sale,
            at: firstVoidDate.addingTimeInterval(100)
        )

        #expect(recorded.sale.voidedAt == firstVoidDate)
        #expect(recorded.sale.updatedAt == firstVoidDate)
        #expect(alert.status == .paused)
        #expect(alert.updatedAt == alertUpdateAfterUserAction)
    }

    @Test("Voiding the earlier partial sale replays the later sale as partial")
    func voidingEarlierSaleReplaysRemainingSales() throws {
        let container = try KaraModelContainerFactory.make(
            arguments: [KaraModelContainerFactory.inMemoryLaunchArgument],
            environment: [:]
        )
        let context = ModelContext(container)
        let repository = SalesRepository(context: context)
        let purchaseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let asset = Asset(
            name: "Lot de trois pièces",
            category: .coin,
            quantity: 3,
            purchaseDate: purchaseDate
        )
        context.insert(asset)
        let alert = try repository.createAlert(
            assetID: asset.id,
            targetValue: 2_000,
            currentValue: 1_800,
            currencyCode: "EUR"
        )
        alert.pause()
        try context.save()

        let earlierSale = try repository.recordSale(
            asset: asset,
            quantity: 1,
            grossAmount: 600,
            soldAt: purchaseDate.addingTimeInterval(20),
            createdAt: purchaseDate.addingTimeInterval(100)
        )
        let laterSale = try repository.recordSale(
            asset: asset,
            quantity: 2,
            grossAmount: 1_200,
            soldAt: purchaseDate.addingTimeInterval(30),
            createdAt: purchaseDate.addingTimeInterval(200)
        )
        #expect(alert.status == .completed)

        try repository.voidSale(
            earlierSale.sale,
            at: purchaseDate.addingTimeInterval(300)
        )

        #expect(try repository.heldQuantity(for: asset) == 1)
        #expect(laterSale.sale.status == .recorded)
        #expect(alert.status == .needsReview)

        try repository.voidSale(
            laterSale.sale,
            at: purchaseDate.addingTimeInterval(400)
        )
        #expect(alert.status == .paused)
    }

    @Test("Voiding the later full sale keeps the earlier partial-sale overlay")
    func voidingLaterSaleReplaysEarlierSale() throws {
        let container = try KaraModelContainerFactory.make(
            arguments: [KaraModelContainerFactory.inMemoryLaunchArgument],
            environment: [:]
        )
        let context = ModelContext(container)
        let repository = SalesRepository(context: context)
        let purchaseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let asset = Asset(
            name: "Lot de trois lingotins",
            category: .bar,
            quantity: 3,
            purchaseDate: purchaseDate
        )
        context.insert(asset)
        let alert = try repository.createAlert(
            assetID: asset.id,
            targetValue: 2_000,
            currentValue: 1_800,
            currencyCode: "EUR"
        )

        let partial = try repository.recordSale(
            asset: asset,
            quantity: 1,
            grossAmount: 600,
            soldAt: purchaseDate.addingTimeInterval(30),
            createdAt: purchaseDate.addingTimeInterval(200)
        )
        let full = try repository.recordSale(
            asset: asset,
            quantity: 2,
            grossAmount: 1_200,
            soldAt: purchaseDate.addingTimeInterval(20),
            createdAt: purchaseDate.addingTimeInterval(300)
        )
        #expect(alert.status == .completed)

        try repository.voidSale(
            full.sale,
            at: purchaseDate.addingTimeInterval(400)
        )

        #expect(try repository.heldQuantity(for: asset) == 2)
        #expect(partial.sale.status == .recorded)
        #expect(alert.status == .needsReview)

        try repository.voidSale(
            partial.sale,
            at: purchaseDate.addingTimeInterval(500)
        )
        #expect(alert.status == .active)
    }

    @Test("Replaying sales preserves an alert review made between two sales")
    func replayPreservesInterveningUserAlertState() throws {
        let container = try KaraModelContainerFactory.make(
            arguments: [KaraModelContainerFactory.inMemoryLaunchArgument],
            environment: [:]
        )
        let context = ModelContext(container)
        let repository = SalesRepository(context: context)
        let asset = Asset(name: "Trois pièces", category: .coin, quantity: 3)
        context.insert(asset)
        let alert = try repository.createAlert(
            assetID: asset.id,
            targetValue: 2_000,
            currentValue: 1_800,
            currencyCode: "EUR"
        )
        _ = try repository.recordSale(
            asset: asset,
            quantity: 1,
            grossAmount: 600,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        #expect(alert.status == .needsReview)

        alert.resume(at: Date(timeIntervalSince1970: 1_700_000_100))
        let laterSale = try repository.recordSale(
            asset: asset,
            quantity: 2,
            grossAmount: 1_200,
            createdAt: Date(timeIntervalSince1970: 1_700_000_200)
        )
        #expect(alert.status == .completed)

        try repository.voidSale(
            laterSale.sale,
            at: Date(timeIntervalSince1970: 1_700_000_300)
        )
        #expect(alert.status == .active)
    }

    @Test("Sale status is authoritative over inconsistent imported line markers")
    func saleStatusIsCanonicalForRepositoryOperations() throws {
        let container = try KaraModelContainerFactory.make(
            arguments: [KaraModelContainerFactory.inMemoryLaunchArgument],
            environment: [:]
        )
        let context = ModelContext(container)
        let repository = SalesRepository(context: context)
        let asset = Asset(name: "Deux pièces", category: .coin, quantity: 2)
        context.insert(asset)

        let first = try repository.recordSale(
            asset: asset,
            quantity: 1,
            grossAmount: 600
        )
        first.line.voidedAt = Date(timeIntervalSince1970: 1_760_000_000)
        try context.save()

        // The line marker is stale, but its authoritative sale is recorded.
        #expect(try repository.heldQuantity(for: asset) == 1)
        let second = try repository.recordSale(
            asset: asset,
            quantity: 1,
            grossAmount: 610
        )
        #expect(try repository.heldQuantity(for: asset) == 0)
        #expect(first.line.voidedAt == nil)

        // The inverse inconsistency must not keep a voided sale in holdings.
        second.sale.status = .voided
        second.sale.voidedAt = Date(timeIntervalSince1970: 1_760_000_100)
        second.line.voidedAt = nil
        try context.save()

        #expect(try repository.heldQuantity(for: asset) == 1)
        #expect(try repository.sales().map(\.id) == [first.sale.id])
    }

    @Test("A voided duplicate sale wins over a stale recorded import")
    func duplicateSaleIDsResolveWithoutResurrectingTheSale() throws {
        let container = try KaraModelContainerFactory.make(
            arguments: [KaraModelContainerFactory.inMemoryLaunchArgument],
            environment: [:]
        )
        let context = ModelContext(container)
        let repository = SalesRepository(context: context)
        let asset = Asset(name: "Pièce unique", category: .coin)
        context.insert(asset)
        let recorded = try repository.recordSale(
            asset: asset,
            quantity: 1,
            grossAmount: 600
        )
        let importedVoid = Sale(
            id: recorded.sale.id,
            soldAt: recorded.sale.soldAt,
            grossAmount: 600,
            createdAt: recorded.sale.createdAt
        )
        importedVoid.status = .voided
        importedVoid.voidedAt = recorded.sale.createdAt.addingTimeInterval(1)
        importedVoid.updatedAt = importedVoid.voidedAt!
        context.insert(importedVoid)
        try context.save()

        #expect(try repository.sales().isEmpty)
        #expect(try repository.sales(includeVoided: true).count == 1)
        #expect(try repository.heldQuantity(for: asset) == 1)

        // Calling with the stale recorded duplicate still cannot restore data.
        try repository.voidSale(recorded.sale)
        #expect(try repository.heldQuantity(for: asset) == 1)
    }

    @Test("Duplicate alert IDs converge deterministically without trapping")
    func duplicateAlertIDsDoNotTrapRepositoryOperations() throws {
        let container = try KaraModelContainerFactory.make(
            arguments: [KaraModelContainerFactory.inMemoryLaunchArgument],
            environment: [:]
        )
        let context = ModelContext(container)
        let repository = SalesRepository(context: context)
        let asset = Asset(name: "Deux lingotins", category: .bar, quantity: 2)
        let alertID = UUID()
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let staleAlert = PriceAlert(
            id: alertID,
            assetID: asset.id,
            targetValueMinorUnits: 70_000,
            currencyCode: "EUR",
            direction: .above,
            status: .active,
            createdAt: createdAt
        )
        let latestAlert = PriceAlert(
            id: alertID,
            assetID: asset.id,
            targetValueMinorUnits: 70_000,
            currencyCode: "EUR",
            direction: .above,
            status: .paused,
            createdAt: createdAt.addingTimeInterval(1)
        )
        context.insert(asset)
        context.insert(staleAlert)
        context.insert(latestAlert)
        try context.save()

        let recorded = try repository.recordSale(
            asset: asset,
            quantity: 1,
            grossAmount: 600,
            createdAt: createdAt.addingTimeInterval(2)
        )
        #expect(try repository.alerts().count == 1)
        #expect(staleAlert.status == .needsReview)
        #expect(latestAlert.status == .needsReview)

        try repository.voidSale(
            recorded.sale,
            at: createdAt.addingTimeInterval(3)
        )
        #expect(staleAlert.status == .paused)
        #expect(latestAlert.status == .paused)
    }

    @Test("A terminal duplicate alert wins over a newer active import")
    func terminalDuplicateAlertCannotBeResurrected() throws {
        let container = try KaraModelContainerFactory.make(
            arguments: [KaraModelContainerFactory.inMemoryLaunchArgument],
            environment: [:]
        )
        let context = ModelContext(container)
        let repository = SalesRepository(context: context)
        let alertID = UUID()
        let assetID = UUID()
        let terminal = PriceAlert(
            id: alertID,
            assetID: assetID,
            targetValueMinorUnits: 300_000,
            currencyCode: "EUR",
            direction: .above,
            status: .cancelled,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        terminal.updatedAt = Date(timeIntervalSince1970: 1_700_000_001)
        let staleActive = PriceAlert(
            id: alertID,
            assetID: assetID,
            targetValueMinorUnits: 300_000,
            currencyCode: "EUR",
            direction: .above,
            status: .active,
            createdAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
        staleActive.updatedAt = Date(timeIntervalSince1970: 1_700_000_100)
        context.insert(terminal)
        context.insert(staleActive)
        try context.save()

        let alerts = try repository.alerts()

        #expect(alerts.count == 1)
        #expect(alerts.first?.status == .cancelled)
    }

    @Test("Malformed alert status or direction requires review")
    func malformedAlertStateIsConservative() {
        let malformedStatus = PriceAlert(
            assetID: UUID(),
            targetValueMinorUnits: 300_000,
            currencyCode: "EUR",
            direction: .above
        )
        malformedStatus.statusRawValue = "unknown-imported-status"

        let malformedDirection = PriceAlert(
            assetID: UUID(),
            targetValueMinorUnits: 300_000,
            currencyCode: "EUR",
            direction: .above
        )
        malformedDirection.directionRawValue = "unknown-imported-direction"

        #expect(malformedStatus.status == .needsReview)
        #expect(malformedDirection.status == .needsReview)
        #expect(!malformedStatus.evaluate(currentValue: 3_100))
        #expect(!malformedDirection.evaluate(currentValue: 3_100))
    }

    @Test("Malformed imported sale status is treated conservatively as voided")
    func malformedSaleStatusDoesNotAffectHoldings() throws {
        let container = try KaraModelContainerFactory.make(
            arguments: [KaraModelContainerFactory.inMemoryLaunchArgument],
            environment: [:]
        )
        let context = ModelContext(container)
        let repository = SalesRepository(context: context)
        let asset = Asset(name: "Pièce unique", category: .coin)
        context.insert(asset)
        let recorded = try repository.recordSale(
            asset: asset,
            quantity: 1,
            grossAmount: 600
        )
        recorded.sale.statusRawValue = "unknown-imported-status"
        try context.save()

        #expect(recorded.sale.status == .voided)
        #expect(try repository.sales().isEmpty)
        #expect(try repository.heldQuantity(for: asset) == 1)
    }

    @Test("Paused alerts do not evaluate and cancelled alerts stay terminal")
    func controlsAlertLifecycle() throws {
        let alert = try PriceAlert.make(
            assetID: UUID(),
            targetValue: 3_000,
            currentValue: 2_800,
            currencyCode: "EUR"
        )

        alert.pause()
        #expect(alert.status == .paused)
        #expect(!alert.evaluate(currentValue: 3_100))

        alert.resume()
        #expect(alert.status == .active)

        alert.cancel()
        #expect(alert.status == .cancelled)
        alert.resume()
        #expect(alert.status == .cancelled)
    }

    @Test("Sale recording rejects invalid quantities and amounts")
    func rejectsInvalidSaleInput() {
        let purchaseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let asset = Asset(
            name: "Pièce unique",
            category: .coin,
            quantity: 1,
            purchaseDate: purchaseDate
        )

        #expect(throws: SaleRecordingError.invalidQuantity) {
            try SalesLedger.record(
                asset: asset,
                quantity: 0,
                grossAmount: 100,
                soldAt: purchaseDate,
                existingSaleLines: [],
                alerts: []
            )
        }
        #expect(
            throws: SaleRecordingError.quantityExceedsHeld(heldQuantity: 1)
        ) {
            try SalesLedger.record(
                asset: asset,
                quantity: 2,
                grossAmount: 200,
                soldAt: purchaseDate,
                existingSaleLines: [],
                alerts: []
            )
        }
        #expect(throws: SaleRecordingError.invalidFeesAmount) {
            try SalesLedger.record(
                asset: asset,
                quantity: 1,
                grossAmount: 100,
                feesAmount: 101,
                soldAt: purchaseDate,
                existingSaleLines: [],
                alerts: []
            )
        }
        #expect(throws: SaleRecordingError.invalidGrossAmount) {
            try SalesLedger.record(
                asset: asset,
                quantity: 1,
                grossAmount: Decimal(string: "0.001")!,
                soldAt: purchaseDate,
                existingSaleLines: [],
                alerts: []
            )
        }
        #expect(throws: SaleRecordingError.salePredatesPurchase) {
            try SalesLedger.record(
                asset: asset,
                quantity: 1,
                grossAmount: 100,
                soldAt: purchaseDate.addingTimeInterval(-86_400),
                existingSaleLines: [],
                alerts: []
            )
        }
    }

    @Test("A sale on the purchase calendar day is accepted")
    func acceptsSaleOnPurchaseDay() throws {
        let purchaseDate = Date(timeIntervalSince1970: 1_700_000_000)
        let asset = Asset(
            name: "Pièce unique",
            category: .coin,
            quantity: 1,
            purchaseDate: purchaseDate
        )

        let recorded = try SalesLedger.record(
            asset: asset,
            quantity: 1,
            grossAmount: 100,
            soldAt: purchaseDate.addingTimeInterval(-1),
            existingSaleLines: [],
            alerts: []
        )

        #expect(recorded.sale.status == .recorded)
    }
}
