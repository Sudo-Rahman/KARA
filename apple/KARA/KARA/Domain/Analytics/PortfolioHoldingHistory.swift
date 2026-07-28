import Foundation

nonisolated struct PortfolioQuantityEvent: Equatable, Sendable {
    let assetID: UUID
    let occurredAt: Date
    let quantity: Int

    init(assetID: UUID, occurredAt: Date, quantity: Int) {
        self.assetID = assetID
        self.occurredAt = occurredAt
        self.quantity = quantity
    }
}

/// A sale event whose asset data is frozen immediately before the sale.
///
/// The identifier is expected to be the stable identifier of the source sale
/// line. The history engine uses it to ignore duplicate inputs.
nonisolated struct PortfolioSaleHistoryEvent: Equatable, Identifiable, Sendable {
    let id: UUID
    let occurredAt: Date
    let soldQuantity: Int
    let assetSnapshotBeforeSale: PortfolioAssetSnapshot

    var assetID: UUID {
        assetSnapshotBeforeSale.id
    }

    init(
        id: UUID = UUID(),
        occurredAt: Date,
        soldQuantity: Int,
        assetSnapshotBeforeSale: PortfolioAssetSnapshot
    ) {
        self.id = id
        self.occurredAt = occurredAt
        self.soldQuantity = soldQuantity
        self.assetSnapshotBeforeSale = assetSnapshotBeforeSale
    }
}

nonisolated struct PortfolioHoldingHistoryEngine: Sendable {
    init() {}

    /// Compatibility entry point for callers that only have quantity events.
    ///
    /// These events cannot protect history from later asset edits because they
    /// do not contain an immutable asset snapshot. New callers should use the
    /// `saleEvents` overload.
    func history(
        assets: [PortfolioAssetSnapshot],
        sales: [PortfolioQuantityEvent],
        market: PortfolioMarketSnapshot,
        asOf: Date = Date(),
        calendar: Calendar = .current
    ) -> [PortfolioHistoryPoint] {
        let assetsByID = Dictionary(
            assets.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let saleEvents = sales.compactMap { event in
            assetsByID[event.assetID].map {
                PortfolioSaleHistoryEvent(
                    occurredAt: event.occurredAt,
                    soldQuantity: event.quantity,
                    assetSnapshotBeforeSale: $0
                )
            }
        }
        return history(
            assets: assets,
            saleEvents: saleEvents,
            market: market,
            asOf: asOf,
            calendar: calendar
        )
    }

    func history(
        assets: [PortfolioAssetSnapshot],
        saleEvents: [PortfolioSaleHistoryEvent],
        market: PortfolioMarketSnapshot,
        asOf: Date = Date(),
        calendar: Calendar = .current
    ) -> [PortfolioHistoryPoint] {
        let currentAssetsByID = Dictionary(
            assets.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let validSales = normalized(
            saleEvents,
            noLaterThan: asOf
        )
        guard !currentAssetsByID.isEmpty || !validSales.isEmpty else {
            return []
        }

        let allKnownAssetVersions = Array(currentAssetsByID.values)
            + validSales.map(\.assetSnapshotBeforeSale)
        let relevantMetals = Set(allKnownAssetVersions.compactMap(\.metal))
        var points: [PortfolioHistoryPoint] = []

        if let monthly = market.monthly {
            let currentMonth = monthIdentifier(for: asOf, calendar: calendar)
            let earliestKnownPurchaseMonth = allKnownAssetVersions
                .compactMap(\.purchaseDate)
                .min()
                .map { monthIdentifier(for: $0, calendar: calendar) }
            let availableMonths = Set(
                monthly.series
                    .filter { relevantMetals.contains($0.metal) }
                    .flatMap(\.observations)
                    .map(\.month)
            )
            .filter { month in
                month < currentMonth
                    && earliestKnownPurchaseMonth.map { month >= $0 } ?? true
            }
            .sorted()

            for month in availableMonths {
                guard let date = endOfMonth(month, calendar: calendar) else {
                    continue
                }
                points.append(
                    point(
                        at: date,
                        currentAssetsByID: currentAssetsByID,
                        saleEvents: validSales,
                        price: { asset in
                            guard let metal = asset.metal else { return nil }
                            return monthly.price(
                                for: metal,
                                currency: .eur,
                                month: month
                            ).map { ($0, monthly.unit.grams) }
                        },
                        isCurrent: false
                    )
                )
            }
        }

        points.append(
            point(
                at: asOf,
                currentAssetsByID: currentAssetsByID,
                saleEvents: validSales,
                price: { asset in
                    guard let metal = asset.metal,
                          let quote = market.quote(for: metal, currency: .eur)
                    else {
                        return nil
                    }
                    return (quote.price, quote.unit.grams)
                },
                isCurrent: true
            )
        )

        return points
    }

    private func point(
        at date: Date,
        currentAssetsByID: [UUID: PortfolioAssetSnapshot],
        saleEvents: [PortfolioSaleHistoryEvent],
        price: (PortfolioAssetSnapshot) -> (value: Decimal, unitGrams: Decimal)?,
        isCurrent: Bool
    ) -> PortfolioHistoryPoint {
        let salesByAssetID = Dictionary(grouping: saleEvents, by: \.assetID)
        let assetIDs = Set(currentAssetsByID.keys)
            .union(salesByAssetID.keys)
            .sorted { $0.uuidString < $1.uuidString }
        let holdings = assetIDs.compactMap {
            assetID -> (PortfolioAssetSnapshot, Int)? in
            let assetSales = salesByAssetID[assetID] ?? []
            let asset = assetSales.first { $0.occurredAt > date }?
                .assetSnapshotBeforeSale
                ?? currentAssetsByID[assetID]
            guard let asset else {
                return nil
            }
            guard asset.purchaseDate.map({ $0 <= date }) ?? true else {
                return nil
            }
            let quantity = assetSales.reduce(
                into: max(0, asset.quantity)
            ) { remaining, event in
                guard event.occurredAt <= date, remaining > 0 else {
                    return
                }
                remaining = max(0, remaining - event.soldQuantity)
            }
            return quantity > 0 ? (asset, quantity) : nil
        }

        let values = holdings.compactMap { asset, quantity -> Decimal? in
            guard let grossWeight = asset.grossWeightGrams,
                  grossWeight > 0,
                  let purity = purity(of: asset),
                  let quote = price(asset),
                  quote.unitGrams > 0
            else {
                return nil
            }
            let fineWeight = Decimal(quantity) * grossWeight * purity
            return fineWeight * quote.value / quote.unitGrams
        }

        return PortfolioHistoryPoint(
            date: date,
            valueEUR: values.reduce(0, +),
            valuedRecordCount: values.count,
            totalHeldRecordCount: holdings.count,
            isCurrent: isCurrent
        )
    }

    private func normalized(
        _ saleEvents: [PortfolioSaleHistoryEvent],
        noLaterThan asOf: Date
    ) -> [PortfolioSaleHistoryEvent] {
        var uniqueEventsByID: [UUID: PortfolioSaleHistoryEvent] = [:]
        var conflictingIDs: Set<UUID> = []

        for event in saleEvents
        where event.soldQuantity > 0
            && event.assetSnapshotBeforeSale.quantity > 0
            && event.soldQuantity <= event.assetSnapshotBeforeSale.quantity
            && event.occurredAt <= asOf {
            if let existing = uniqueEventsByID[event.id],
               existing != event {
                conflictingIDs.insert(event.id)
                continue
            }
            uniqueEventsByID[event.id] = event
        }

        return uniqueEventsByID.values
            .filter { !conflictingIDs.contains($0.id) }
            .sorted {
                if $0.occurredAt != $1.occurredAt {
                    return $0.occurredAt < $1.occurredAt
                }
                return $0.id.uuidString < $1.id.uuidString
            }
    }

    private func purity(of asset: PortfolioAssetSnapshot) -> Decimal? {
        if let fineness = asset.finenessPermille,
           fineness > 0,
           fineness <= 1_000 {
            return fineness / 1_000
        }
        if let karat = asset.metalKarat,
           karat > 0,
           karat <= 24 {
            return karat / 24
        }
        return nil
    }

    private func monthIdentifier(
        for date: Date,
        calendar: Calendar
    ) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        return String(
            format: "%04d-%02d",
            components.year ?? 0,
            components.month ?? 0
        )
    }

    private func endOfMonth(
        _ identifier: String,
        calendar: Calendar
    ) -> Date? {
        let parts = identifier.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              (1...12).contains(month),
              let start = calendar.date(
                  from: DateComponents(year: year, month: month, day: 1)
              ),
              let nextMonth = calendar.date(
                  byAdding: .month,
                  value: 1,
                  to: start
              )
        else {
            return nil
        }
        return calendar.date(byAdding: .second, value: -1, to: nextMonth)
    }
}
