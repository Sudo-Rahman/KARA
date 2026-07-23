import Foundation

nonisolated enum AssetTrashPolicy {
    static let retentionDays = 30

    static func expirationCutoff(
        asOf date: Date,
        calendar: Calendar = .current
    ) -> Date {
        calendar.date(byAdding: .day, value: -retentionDays, to: date)
            ?? date.addingTimeInterval(-Double(retentionDays) * 86_400)
    }
}
