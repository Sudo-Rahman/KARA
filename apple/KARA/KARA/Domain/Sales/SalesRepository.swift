import Foundation
import SwiftData

@MainActor
final class SalesRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func sales(includeVoided: Bool = false) throws -> [Sale] {
        Self.canonicalSales(from: try rawSales())
            .filter { includeVoided || $0.status == .recorded }
            .sorted { lhs, rhs in
                if lhs.soldAt == rhs.soldAt {
                    if lhs.createdAt == rhs.createdAt {
                        return lhs.id.uuidString < rhs.id.uuidString
                    }
                    return lhs.createdAt > rhs.createdAt
                }
                return lhs.soldAt > rhs.soldAt
            }
    }

    func saleLines(for saleID: UUID? = nil) throws -> [SaleLine] {
        let salesByID = Self.canonicalSalesByID(from: try rawSales())
        return Self.canonicalSaleLines(
            from: try rawSaleLines(),
            salesByID: salesByID
        )
            .filter { saleID == nil || $0.saleID == saleID }
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }

    func recordedSaleLines() throws -> [SaleLine] {
        let salesByID = Self.canonicalSalesByID(from: try rawSales())
        return Self.recordedSaleLines(
            from: try rawSaleLines(),
            salesByID: salesByID
        )
        .sorted { $0.id.uuidString < $1.id.uuidString }
    }

    func alerts(for assetID: UUID? = nil) throws -> [PriceAlert] {
        Self.canonicalAlerts(from: try rawAlerts())
            .filter { assetID == nil || $0.assetID == assetID }
            .sorted {
                if $0.createdAt == $1.createdAt {
                    return $0.id.uuidString < $1.id.uuidString
                }
                return $0.createdAt > $1.createdAt
            }
    }

    func heldQuantity(for asset: Asset) throws -> Int {
        let salesByID = Self.canonicalSalesByID(from: try rawSales())
        let recordedLines = Self.recordedSaleLines(
            from: try rawSaleLines(),
            salesByID: salesByID
        )
        return SalesLedger.heldQuantity(
            for: asset,
            recordedSaleLines: recordedLines
        )
    }

    @discardableResult
    func recordSale(
        asset: Asset,
        quantity: Int,
        grossAmount: Decimal,
        feesAmount: Decimal = 0,
        currencyCode: String = "EUR",
        soldAt: Date = Date(),
        buyerName: String? = nil,
        note: String? = nil,
        spotValueAtSale: Decimal? = nil,
        createdAt: Date = Date()
    ) throws -> RecordedSale {
        let persistedSales = try rawSales()
        let persistedLines = try rawSaleLines()
        let persistedAlerts = try rawAlerts()
        let salesByID = Self.canonicalSalesByID(from: persistedSales)
        let recordedLines = Self.recordedSaleLines(
            from: persistedLines,
            salesByID: salesByID
        )
        let representativeAlerts = Self.canonicalAlerts(
            from: persistedAlerts
        ).filter { $0.assetID == asset.id }

        let recorded = try SalesLedger.record(
            asset: asset,
            quantity: quantity,
            grossAmount: grossAmount,
            feesAmount: feesAmount,
            currencyCode: currencyCode,
            soldAt: soldAt,
            buyerName: buyerName,
            note: note,
            spotValueAtSale: spotValueAtSale,
            existingSaleLines: recordedLines,
            existingRecordedSaleLines: recordedLines,
            alerts: representativeAlerts,
            createdAt: createdAt
        )

        context.insert(recorded.sale)
        context.insert(recorded.line)

        let resultingSales = persistedSales + [recorded.sale]
        let resultingLines = persistedLines + [recorded.line]
        synchronizeLineMarkers(
            resultingLines,
            salesByID: Self.canonicalSalesByID(from: resultingSales),
            fallbackDate: createdAt
        )
        synchronizeDuplicateAlerts(
            persistedAlerts,
            representatives: representativeAlerts
        )
        try saveOrRollback()
        return recorded
    }

    func voidSale(
        _ sale: Sale,
        at date: Date = Date()
    ) throws {
        // Idempotency is deliberately checked before fetching or restoring any
        // related state. A repeated UI action or sync replay is a true no-op.
        guard sale.status == .recorded else { return }

        let persistedSales = try rawSales()
        let matchingSales = persistedSales.filter { $0.id == sale.id }
        guard let canonicalSale = Self.preferredSale(from: matchingSales),
              canonicalSale.status == .recorded
        else {
            return
        }

        let persistedLines = try rawSaleLines()
        let matchingLines = persistedLines.filter { $0.saleID == sale.id }
        let affectedAlertIDs = Set(
            matchingLines
                .flatMap(\.alertStateSnapshots)
                .map(\.alertID)
        )

        // Converge duplicate imported Sale rows to the same monotonic state.
        // Sale is the authority; every associated line is only a projection.
        for matchingSale in matchingSales {
            _ = matchingSale.void(lines: matchingLines, at: date)
        }
        for line in matchingLines {
            line.voidedAt = date
        }

        let salesByID = Self.canonicalSalesByID(from: persistedSales)
        let persistedAlerts = try rawAlerts()
        replaySaleOverlays(
            affectedAlertIDs: affectedAlertIDs,
            salesByID: salesByID,
            lines: persistedLines,
            alerts: persistedAlerts,
            at: date
        )
        synchronizeLineMarkers(
            persistedLines,
            salesByID: salesByID,
            fallbackDate: date
        )
        try saveOrRollback()
    }

    @discardableResult
    func createAlert(
        assetID: UUID,
        targetValue: Decimal,
        currentValue: Decimal,
        currencyCode: String,
        createdAt: Date = Date()
    ) throws -> PriceAlert {
        let alert = try PriceAlert.make(
            assetID: assetID,
            targetValue: targetValue,
            currentValue: currentValue,
            currencyCode: currencyCode,
            createdAt: createdAt
        )
        context.insert(alert)
        try saveOrRollback()
        return alert
    }

    private func rawSales() throws -> [Sale] {
        try context.fetch(FetchDescriptor<Sale>())
    }

    private func rawSaleLines() throws -> [SaleLine] {
        try context.fetch(FetchDescriptor<SaleLine>())
    }

    private func rawAlerts() throws -> [PriceAlert] {
        try context.fetch(FetchDescriptor<PriceAlert>())
    }

    static func canonicalSales(from values: [Sale]) -> [Sale] {
        Dictionary(grouping: values, by: \.id)
            .values
            .compactMap { preferredSale(from: $0) }
    }

    static func canonicalSalesByID(from values: [Sale]) -> [UUID: Sale] {
        var result: [UUID: Sale] = [:]
        for sale in canonicalSales(from: values) {
            result[sale.id] = sale
        }
        return result
    }

    private static func preferredSale(from values: [Sale]) -> Sale? {
        values.sorted(by: saleIsPreferred).first
    }

    private static func saleIsPreferred(_ lhs: Sale, _ rhs: Sale) -> Bool {
        if lhs.status != rhs.status {
            // Voiding is monotonic. A stale recorded duplicate must never
            // resurrect a logical sale after a CloudKit merge.
            return lhs.status == .voided
        }
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }
        if lhs.soldAt != rhs.soldAt {
            return lhs.soldAt > rhs.soldAt
        }
        if lhs.grossAmountMinorUnits != rhs.grossAmountMinorUnits {
            return lhs.grossAmountMinorUnits > rhs.grossAmountMinorUnits
        }
        if lhs.feesAmountMinorUnits != rhs.feesAmountMinorUnits {
            return lhs.feesAmountMinorUnits > rhs.feesAmountMinorUnits
        }
        return lhs.currencyCode < rhs.currencyCode
    }

    static func canonicalSaleLines(
        from values: [SaleLine],
        salesByID: [UUID: Sale]
    ) -> [SaleLine] {
        // The product records exactly one immutable line for each sale. Grouping
        // by the authoritative sale ID also collapses CloudKit duplicates that
        // were materialized with different local line IDs.
        Dictionary(
            grouping: values.filter { salesByID[$0.saleID] != nil },
            by: \.saleID
        )
            .values
            .compactMap { duplicates in
                guard let saleID = duplicates.first?.saleID,
                      let sale = salesByID[saleID]
                else {
                    return nil
                }
                return duplicates.sorted {
                    saleLineIsPreferred($0, $1, sale: sale)
                }
                .first
            }
    }

    private static func saleLineIsPreferred(
        _ lhs: SaleLine,
        _ rhs: SaleLine,
        sale: Sale
    ) -> Bool {
        let lhsScore = saleLineIntegrityScore(lhs, sale: sale)
        let rhsScore = saleLineIntegrityScore(rhs, sale: sale)
        if lhsScore != rhsScore {
            return lhsScore > rhsScore
        }
        let lhsCompleteness = saleLineSnapshotCompleteness(lhs)
        let rhsCompleteness = saleLineSnapshotCompleteness(rhs)
        if lhsCompleteness != rhsCompleteness {
            return lhsCompleteness > rhsCompleteness
        }
        if lhs.id != rhs.id {
            return lhs.id.uuidString < rhs.id.uuidString
        }
        return saleLineStableContentKey(lhs) < saleLineStableContentKey(rhs)
    }

    private static func saleLineIntegrityScore(
        _ line: SaleLine,
        sale: Sale
    ) -> Int {
        var score = 0
        if line.saleCurrencyCode == sale.currencyCode {
            score += 8
        }
        if line.grossProceedsMinorUnits == sale.grossAmountMinorUnits {
            score += 8
        }
        if line.quantity > 0,
           line.assetQuantitySnapshot > 0,
           line.quantity <= line.assetQuantitySnapshot {
            score += 4
        }
        if allocatedPurchaseCostIsConsistent(line) {
            score += 2
        }
        if !line.assetNameSnapshot
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty {
            score += 1
        }
        return score
    }

    private static func allocatedPurchaseCostIsConsistent(
        _ line: SaleLine
    ) -> Bool {
        guard let purchaseCostMinorUnits =
                line.purchaseCostMinorUnitsSnapshot
        else {
            return line.allocatedPurchaseCostMinorUnitsSnapshot == nil
        }
        guard line.assetQuantitySnapshot > 0,
              line.quantity > 0,
              line.quantity <= line.assetQuantitySnapshot,
              let purchaseCost = MoneyConverter.decimalAmount(
                  from: purchaseCostMinorUnits,
                  currencyCode: line.purchaseCurrencyCodeSnapshot
              ),
              let expectedMinorUnits = MoneyConverter.minorUnits(
                  from: purchaseCost
                      * Decimal(line.quantity)
                      / Decimal(line.assetQuantitySnapshot),
                  currencyCode: line.purchaseCurrencyCodeSnapshot
              )
        else {
            return false
        }
        return line.allocatedPurchaseCostMinorUnitsSnapshot
            == expectedMinorUnits
    }

    private static func saleLineSnapshotCompleteness(
        _ line: SaleLine
    ) -> Int {
        [
            line.purchaseDateSnapshot != nil,
            line.metalRawValueSnapshot != nil,
            line.weightGramsSnapshot != nil,
            line.metalKaratSnapshot != nil
                || line.finenessPermilleSnapshot != nil,
            line.purchaseCostMinorUnitsSnapshot != nil,
            line.sellerNameSnapshot != nil,
            line.storageLocationNameSnapshot != nil,
            line.invoiceNumberSnapshot != nil,
            line.serialNumberSnapshot != nil,
        ]
        .count(where: { $0 })
    }

    private static func saleLineStableContentKey(
        _ line: SaleLine
    ) -> String {
        [
            line.assetID.uuidString,
            String(line.quantity),
            String(line.assetQuantitySnapshot),
            String(line.grossProceedsMinorUnits),
            line.saleCurrencyCode,
            line.assetNameSnapshot,
            line.categoryRawValueSnapshot,
            String(line.purchaseCostMinorUnitsSnapshot ?? .min),
            String(line.allocatedPurchaseCostMinorUnitsSnapshot ?? .min),
        ]
        .joined(separator: "|")
    }

    static func recordedSaleLines(
        from values: [SaleLine],
        salesByID: [UUID: Sale]
    ) -> [SaleLine] {
        canonicalSaleLines(
            from: values,
            salesByID: salesByID
        ).filter { line in
            salesByID[line.saleID]?.status == .recorded
        }
    }

    static func canonicalAlerts(from values: [PriceAlert]) -> [PriceAlert] {
        Dictionary(grouping: values, by: \.id)
            .values
            .compactMap { duplicates in
                duplicates.sorted(by: alertIsPreferred).first
            }
    }

    private static func alertIsPreferred(
        _ lhs: PriceAlert,
        _ rhs: PriceAlert
    ) -> Bool {
        if lhs.status.isTerminal != rhs.status.isTerminal {
            // Triggering, completing, and cancelling are monotonic. A stale
            // active/paused/review duplicate must never resurrect monitoring,
            // even when its device clock produced a later updatedAt value.
            return lhs.status.isTerminal
        }
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt > rhs.updatedAt
        }
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }
        if lhs.status.integrityPriority != rhs.status.integrityPriority {
            return lhs.status.integrityPriority > rhs.status.integrityPriority
        }
        if lhs.assetID != rhs.assetID {
            return lhs.assetID.uuidString < rhs.assetID.uuidString
        }
        return lhs.targetValueMinorUnits > rhs.targetValueMinorUnits
    }

    private func synchronizeDuplicateAlerts(
        _ alerts: [PriceAlert],
        representatives: [PriceAlert]
    ) {
        var representativesByID: [UUID: PriceAlert] = [:]
        for alert in representatives {
            representativesByID[alert.id] = alert
        }
        for alert in alerts {
            guard let representative = representativesByID[alert.id],
                  alert !== representative
            else {
                continue
            }
            alert.status = representative.status
            alert.updatedAt = representative.updatedAt
        }
    }

    private func synchronizeLineMarkers(
        _ lines: [SaleLine],
        salesByID: [UUID: Sale],
        fallbackDate: Date
    ) {
        for line in lines {
            guard let sale = salesByID[line.saleID] else {
                // Orphaned imported lines cannot affect holdings without their
                // authoritative Sale record.
                line.voidedAt = line.voidedAt ?? fallbackDate
                continue
            }
            switch sale.status {
            case .recorded:
                line.voidedAt = nil
            case .voided:
                line.voidedAt = sale.voidedAt ?? sale.updatedAt
            }
        }
    }

    private func replaySaleOverlays(
        affectedAlertIDs: Set<UUID>,
        salesByID: [UUID: Sale],
        lines: [SaleLine],
        alerts: [PriceAlert],
        at date: Date
    ) {
        guard !affectedAlertIDs.isEmpty else { return }

        let canonicalLines = Self.canonicalSaleLines(
            from: lines,
            salesByID: salesByID
        )
        let alertGroups = Dictionary(grouping: alerts, by: \.id)
        for alertID in affectedAlertIDs.sorted(
            by: { $0.uuidString < $1.uuidString }
        ) {
            guard let duplicates = alertGroups[alertID],
                  let representative = duplicates.sorted(
                      by: Self.alertIsPreferred
                  ).first
            else {
                continue
            }

            let events = alertSnapshotEvents(
                for: representative,
                lines: canonicalLines,
                salesByID: salesByID
            )
            guard !events.isEmpty else { continue }

            let reconciledStatus = reconciledAlertStatus(
                currentStatus: representative.status,
                events: events,
                alert: representative,
                lines: canonicalLines,
                salesByID: salesByID
            )
            for alert in duplicates {
                guard alert.status != reconciledStatus else { continue }
                alert.status = reconciledStatus
                alert.updatedAt = date
            }
        }
    }

    private func alertSnapshotEvents(
        for alert: PriceAlert,
        lines: [SaleLine],
        salesByID: [UUID: Sale]
    ) -> [AlertSnapshotEvent] {
        lines.compactMap { line in
            guard line.assetID == alert.assetID,
                  let sale = salesByID[line.saleID],
                  let snapshot = line.alertStateSnapshots
                    .filter({ $0.alertID == alert.id })
                    .sorted(by: snapshotIsPreferred)
                    .first
            else {
                return nil
            }
            return AlertSnapshotEvent(
                sale: sale,
                line: line,
                snapshot: snapshot
            )
        }
        .sorted(by: alertEventComesBefore)
    }

    private func snapshotIsPreferred(
        _ lhs: SaleAlertStateSnapshot,
        _ rhs: SaleAlertStateSnapshot
    ) -> Bool {
        if lhs.previousStatus.rawValue != rhs.previousStatus.rawValue {
            return lhs.previousStatus.rawValue < rhs.previousStatus.rawValue
        }
        return lhs.appliedStatus.rawValue < rhs.appliedStatus.rawValue
    }

    private func alertEventComesBefore(
        _ lhs: AlertSnapshotEvent,
        _ rhs: AlertSnapshotEvent
    ) -> Bool {
        if lhs.sale.createdAt != rhs.sale.createdAt {
            return lhs.sale.createdAt < rhs.sale.createdAt
        }
        if lhs.sale.soldAt != rhs.sale.soldAt {
            return lhs.sale.soldAt < rhs.sale.soldAt
        }
        return lhs.line.id.uuidString < rhs.line.id.uuidString
    }

    private func reconciledAlertStatus(
        currentStatus: PriceAlertStatus,
        events: [AlertSnapshotEvent],
        alert: PriceAlert,
        lines: [SaleLine],
        salesByID: [UUID: Sale]
    ) -> PriceAlertStatus {
        // Terminal states and explicit user acknowledgement win over a sale
        // overlay. The current schema cannot reconstruct richer user history.
        guard currentStatus.isSaleOverlay else {
            return currentStatus
        }

        let userBase = userBaseState(from: events)
        let baseStatus = userBase.status
        let overlayEvents = Array(events[userBase.overlayStartIndex...])
        let remainingEvents = overlayEvents.filter {
            $0.sale.status == .recorded
        }
        guard !remainingEvents.isEmpty else {
            return baseStatus
        }

        let activeAssetLines = lines
            .filter {
                $0.assetID == alert.assetID
                    && salesByID[$0.saleID]?.status == .recorded
            }
            .sorted { lhs, rhs in
                guard let lhsSale = salesByID[lhs.saleID],
                      let rhsSale = salesByID[rhs.saleID]
                else {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                if lhsSale.soldAt != rhsSale.soldAt {
                    return lhsSale.soldAt < rhsSale.soldAt
                }
                if lhsSale.createdAt != rhsSale.createdAt {
                    return lhsSale.createdAt < rhsSale.createdAt
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        let assetQuantity = lines
            .filter { $0.assetID == alert.assetID }
            .map(\.assetQuantitySnapshot)
            .filter { $0 > 0 }
            .max()
        guard let assetQuantity else {
            return remainingEvents.last?.snapshot.appliedStatus
                ?? baseStatus
        }

        // Replay in business chronology. Lines predating the alert still
        // contribute to held quantity, but the overlay starts only once a
        // remaining sale that actually captured this alert is encountered.
        let overlaySaleIDs = Set(remainingEvents.map(\.sale.id))
        var soldQuantity = 0
        var replayedStatus = baseStatus
        var overlayStarted = false
        for line in activeAssetLines {
            soldQuantity += max(0, line.quantity)
            overlayStarted = overlayStarted
                || overlaySaleIDs.contains(line.saleID)
            guard overlayStarted else { continue }
            replayedStatus = soldQuantity >= assetQuantity
                ? .completed
                : .needsReview
        }
        return replayedStatus
    }

    private func userBaseState(
        from events: [AlertSnapshotEvent]
    ) -> AlertUserBaseState {
        var result = events[0].snapshot.previousStatus
        var overlayStartIndex = 0
        var historicalAppliedStatus: PriceAlertStatus?

        for (index, event) in events.enumerated() {
            let previous = event.snapshot.previousStatus
            if historicalAppliedStatus == nil {
                result = previous
            } else if previous != historicalAppliedStatus,
                      previous.isUserBaseStatus {
                // A later snapshot can reveal that the user resumed or paused
                // the alert between two sales.
                result = previous
                overlayStartIndex = index
            }
            historicalAppliedStatus = event.snapshot.appliedStatus
        }
        return AlertUserBaseState(
            status: result,
            overlayStartIndex: overlayStartIndex
        )
    }

    private func saveOrRollback() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}

private struct AlertSnapshotEvent {
    let sale: Sale
    let line: SaleLine
    let snapshot: SaleAlertStateSnapshot
}

private struct AlertUserBaseState {
    let status: PriceAlertStatus
    let overlayStartIndex: Int
}

private extension PriceAlertStatus {
    var isTerminal: Bool {
        switch self {
        case .triggered, .completed, .cancelled:
            true
        case .active, .paused, .needsReview:
            false
        }
    }

    var isSaleOverlay: Bool {
        self == .needsReview || self == .completed
    }

    var isUserBaseStatus: Bool {
        switch self {
        case .active, .paused, .triggered, .cancelled:
            true
        case .needsReview, .completed:
            false
        }
    }

    var integrityPriority: Int {
        switch self {
        case .cancelled:
            6
        case .triggered:
            5
        case .completed:
            4
        case .needsReview:
            3
        case .paused:
            2
        case .active:
            1
        }
    }
}
