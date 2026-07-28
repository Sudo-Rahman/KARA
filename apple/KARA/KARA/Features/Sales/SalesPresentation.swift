import Foundation

nonisolated enum SalesFormValidationError: Equatable, Sendable {
    case invalidGrossAmount
    case invalidFees
    case feesExceedGrossAmount
    case invalidQuantity
    case quantityExceedsHolding
    case salePredatesPurchase
}

nonisolated enum SalesFormValidator {
    static func validate(
        grossAmount: Decimal?,
        feesAmount: Decimal?,
        quantity: Int,
        heldQuantity: Int,
        soldAt: Date? = nil,
        purchaseDate: Date? = nil,
        calendar: Calendar = .current
    ) -> SalesFormValidationError? {
        guard let grossAmount, grossAmount > 0 else {
            return .invalidGrossAmount
        }
        guard let feesAmount, feesAmount >= 0 else {
            return .invalidFees
        }
        guard feesAmount <= grossAmount else {
            return .feesExceedGrossAmount
        }
        guard quantity > 0 else {
            return .invalidQuantity
        }
        guard quantity <= heldQuantity else {
            return .quantityExceedsHolding
        }
        if let soldAt,
           let purchaseDate,
           calendar.compare(
               soldAt,
               to: purchaseDate,
               toGranularity: .day
           ) == .orderedAscending {
            return .salePredatesPurchase
        }
        return nil
    }
}

nonisolated enum SalesAmountParser {
    static func amount(
        from text: String,
        locale: Locale = .current
    ) -> Decimal? {
        let normalized = text
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: "\u{202F}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.generatesDecimalNumbers = true

        if let number = formatter.number(from: normalized) {
            return number.decimalValue
        }

        let decimalSeparator = locale.decimalSeparator ?? "."
        let fallback = normalized
            .replacingOccurrences(of: locale.groupingSeparator ?? " ", with: "")
            .replacingOccurrences(of: decimalSeparator, with: ".")
        return Decimal(
            string: fallback,
            locale: Locale(identifier: "en_US_POSIX")
        )
    }
}

nonisolated struct SaleSuccessPresentation: Equatable, Sendable {
    let saleID: UUID
    let assetName: String
    let netAmount: Decimal
    let currencyCode: String
    let disposition: SaleDisposition
}

extension PriceAlertStatus {
    var salesStatusKey: String.LocalizationValue {
        switch self {
        case .active:
            "sales.alert.status.active"
        case .paused:
            "sales.alert.status.paused"
        case .needsReview:
            "sales.alert.status.review"
        case .triggered:
            "sales.alert.status.reached"
        case .completed:
            "sales.alert.status.completed"
        case .cancelled:
            "sales.alert.status.cancelled"
        }
    }
}

extension PriceAlertDirection {
    var salesConditionKey: String.LocalizationValue {
        switch self {
        case .above:
            "sales.alert.condition.above"
        case .below:
            "sales.alert.condition.below"
        }
    }
}
