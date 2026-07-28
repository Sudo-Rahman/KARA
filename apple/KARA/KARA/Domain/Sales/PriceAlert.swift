import Foundation
import SwiftData

nonisolated enum PriceAlertDirection: String, Codable, Sendable {
    case above
    case below
}

nonisolated enum PriceAlertStatus: String, Codable, Sendable {
    case active
    case paused
    case needsReview
    case triggered
    case completed
    case cancelled
}

nonisolated enum PriceAlertError: Error, Equatable {
    case invalidCurrency
    case invalidTargetValue
    case targetEqualsCurrentValue
}

@Model
final class PriceAlert {
    var id: UUID = UUID()
    var assetID: UUID = UUID()
    var targetValueMinorUnits: Int64 = 0
    var currencyCode: String = "EUR"
    var directionRawValue: String = PriceAlertDirection.above.rawValue
    var statusRawValue: String = PriceAlertStatus.active.rawValue
    var lastObservedValueMinorUnits: Int64?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var lastCheckedAt: Date?
    var triggeredAt: Date?

    var targetValue: Decimal {
        MoneyConverter.decimalAmount(
            from: targetValueMinorUnits,
            currencyCode: currencyCode
        ) ?? 0
    }

    var lastObservedValue: Decimal? {
        lastObservedValueMinorUnits.flatMap {
            MoneyConverter.decimalAmount(
                from: $0,
                currencyCode: currencyCode
            )
        }
    }

    var direction: PriceAlertDirection {
        get {
            PriceAlertDirection(rawValue: directionRawValue) ?? .above
        }
        set {
            directionRawValue = newValue.rawValue
        }
    }

    var status: PriceAlertStatus {
        get {
            guard PriceAlertDirection(rawValue: directionRawValue) != nil,
                  let status = PriceAlertStatus(rawValue: statusRawValue)
            else {
                // Imported or migrated alert data must never become monitorable
                // through a permissive fallback. The raw direction remains
                // available for diagnosis, while the effective status is inert.
                return .needsReview
            }
            return status
        }
        set {
            statusRawValue = newValue.rawValue
        }
    }

    init(
        id: UUID = UUID(),
        assetID: UUID,
        targetValueMinorUnits: Int64,
        currencyCode: String,
        direction: PriceAlertDirection,
        status: PriceAlertStatus = .active,
        lastObservedValueMinorUnits: Int64? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.assetID = assetID
        self.targetValueMinorUnits = targetValueMinorUnits
        self.currencyCode = currencyCode
        directionRawValue = direction.rawValue
        statusRawValue = status.rawValue
        self.lastObservedValueMinorUnits = lastObservedValueMinorUnits
        self.createdAt = createdAt
        updatedAt = createdAt
    }

    static func make(
        assetID: UUID,
        targetValue: Decimal,
        currentValue: Decimal,
        currencyCode: String,
        createdAt: Date = Date()
    ) throws -> PriceAlert {
        let normalizedCurrencyCode = currencyCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased(with: Locale(identifier: "en_US_POSIX"))

        guard MoneyConverter.isSupportedCurrencyCode(normalizedCurrencyCode)
        else {
            throw PriceAlertError.invalidCurrency
        }
        guard targetValue > 0,
              let targetMinorUnits = MoneyConverter.minorUnits(
                  from: targetValue,
                  currencyCode: normalizedCurrencyCode
              ),
              let currentMinorUnits = MoneyConverter.minorUnits(
                  from: currentValue,
                  currencyCode: normalizedCurrencyCode
              )
        else {
            throw PriceAlertError.invalidTargetValue
        }
        guard targetMinorUnits != currentMinorUnits else {
            throw PriceAlertError.targetEqualsCurrentValue
        }

        return PriceAlert(
            assetID: assetID,
            targetValueMinorUnits: targetMinorUnits,
            currencyCode: normalizedCurrencyCode,
            direction: targetMinorUnits > currentMinorUnits ? .above : .below,
            lastObservedValueMinorUnits: currentMinorUnits,
            createdAt: createdAt
        )
    }

    @discardableResult
    func evaluate(
        currentValue: Decimal,
        at date: Date = Date()
    ) -> Bool {
        guard status == .active,
              let currentMinorUnits = MoneyConverter.minorUnits(
                  from: currentValue,
                  currencyCode: currencyCode
              )
        else {
            return false
        }

        lastObservedValueMinorUnits = currentMinorUnits
        lastCheckedAt = date
        updatedAt = date

        let reached = switch direction {
        case .above:
            currentMinorUnits >= targetValueMinorUnits
        case .below:
            currentMinorUnits <= targetValueMinorUnits
        }

        guard reached else { return false }

        status = .triggered
        triggeredAt = date
        return true
    }

    func markNeedsReview(at date: Date = Date()) {
        guard status == .active
                || status == .paused
                || status == .needsReview
        else {
            return
        }

        status = .needsReview
        updatedAt = date
    }

    func completeDueToSale(at date: Date = Date()) {
        guard status == .active
                || status == .paused
                || status == .needsReview
        else {
            return
        }

        status = .completed
        updatedAt = date
    }

    func pause(at date: Date = Date()) {
        guard status == .active else { return }
        status = .paused
        updatedAt = date
    }

    func resume(at date: Date = Date()) {
        guard status == .paused || status == .needsReview else { return }
        status = .active
        updatedAt = date
    }

    func cancel(at date: Date = Date()) {
        guard status == .active
                || status == .paused
                || status == .needsReview
        else {
            return
        }
        status = .cancelled
        updatedAt = date
    }
}
