import Foundation
import SwiftData

nonisolated enum SaleStatus: String, Codable, Sendable {
    case recorded
    case voided
}

@Model
final class Sale {
    var id: UUID = UUID()
    var soldAt: Date = Date()
    var grossAmountMinorUnits: Int64 = 0
    var feesAmountMinorUnits: Int64 = 0
    var currencyCode: String = "EUR"
    var buyerName: String?
    var note: String?
    var statusRawValue: String = SaleStatus.recorded.rawValue
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var voidedAt: Date?

    var grossAmount: Decimal {
        MoneyConverter.decimalAmount(
            from: grossAmountMinorUnits,
            currencyCode: currencyCode
        ) ?? 0
    }

    var feesAmount: Decimal {
        MoneyConverter.decimalAmount(
            from: feesAmountMinorUnits,
            currencyCode: currencyCode
        ) ?? 0
    }

    var netAmount: Decimal {
        grossAmount - feesAmount
    }

    var status: SaleStatus {
        // A malformed imported status must never resurrect a sale. New and
        // legacy records both persist the explicit "recorded" default.
        get { SaleStatus(rawValue: statusRawValue) ?? .voided }
        set { statusRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        soldAt: Date = Date(),
        grossAmount: Decimal,
        feesAmount: Decimal = 0,
        currencyCode: String = "EUR",
        buyerName: String? = nil,
        note: String? = nil,
        createdAt: Date = Date()
    ) {
        let normalizedCurrencyCode = currencyCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased(with: Locale(identifier: "en_US_POSIX"))

        self.id = id
        self.soldAt = soldAt
        grossAmountMinorUnits = MoneyConverter.minorUnits(
            from: grossAmount,
            currencyCode: normalizedCurrencyCode
        ) ?? 0
        feesAmountMinorUnits = MoneyConverter.minorUnits(
            from: feesAmount,
            currencyCode: normalizedCurrencyCode
        ) ?? 0
        self.currencyCode = normalizedCurrencyCode
        self.buyerName = buyerName
        self.note = note
        self.createdAt = createdAt
        updatedAt = createdAt
    }

    @discardableResult
    func void(lines: [SaleLine], at date: Date = Date()) -> Bool {
        guard status == .recorded else { return false }

        status = .voided
        voidedAt = date
        updatedAt = date

        for line in lines where line.saleID == id {
            line.voidedAt = date
        }
        return true
    }
}
