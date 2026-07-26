import Foundation

extension VaultFormatters {
    nonisolated static func reportCurrency(
        _ value: Decimal,
        code: String,
        locale: Locale,
        showsPositiveSign: Bool = false
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = true
        if showsPositiveSign, value > 0 {
            formatter.positivePrefix = "+\(formatter.positivePrefix ?? "")"
        }
        return formatter.string(from: NSDecimalNumber(decimal: value))
            ?? NSDecimalNumber(decimal: value).stringValue
    }

    nonisolated static func reportPercentage(
        _ value: Decimal,
        locale: Locale,
        showsPositiveSign: Bool = false
    ) -> String {
        "\(reportDecimal(value, locale: locale, maximumFractionDigits: 1, showsPositiveSign: showsPositiveSign))\u{00A0}%"
    }

    nonisolated static func reportWeight(_ value: Decimal, locale: Locale) -> String {
        "\(reportDecimal(value, locale: locale, maximumFractionDigits: 2))\u{00A0}g"
    }

    nonisolated static func reportDecimal(
        _ value: Decimal,
        locale: Locale,
        maximumFractionDigits: Int = 2,
        showsPositiveSign: Bool = false
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.usesGroupingSeparator = true
        if showsPositiveSign, value > 0 {
            formatter.positivePrefix = "+"
        }
        return formatter.string(from: NSDecimalNumber(decimal: value))
            ?? NSDecimalNumber(decimal: value).stringValue
    }

    nonisolated static func reportInteger(_ value: Int, locale: Locale) -> String {
        reportDecimal(Decimal(value), locale: locale, maximumFractionDigits: 0)
    }

    nonisolated static func reportDate(_ value: Date, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: value)
    }

    nonisolated static func reportDateTime(_ value: Date, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: value)
    }

    nonisolated static func reportByteCount(_ value: Int64, locale: Locale) -> String {
        value.formatted(ByteCountFormatStyle(style: .file).locale(locale))
    }
}
