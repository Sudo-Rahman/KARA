import CoreTransferable
import Foundation
import UniformTypeIdentifiers

nonisolated struct VaultReportTransfer: Transferable, Sendable {
    let data: Data
    let filename: String

    init(
        data: Data,
        generatedAt: Date,
        calendar: Calendar = .current
    ) {
        self.data = data
        filename = Self.suggestedFilename(for: generatedAt, calendar: calendar)
    }

    static func suggestedFilename(
        for generatedAt: Date,
        calendar: Calendar = .current
    ) -> String {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let components = gregorian.dateComponents(
            [.year, .month, .day],
            from: generatedAt
        )
        return String(
            format: "Rapport-Coffre-KARA-%04d-%02d-%02d.pdf",
            locale: Locale(identifier: "en_US_POSIX"),
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .pdf) { transfer in
            transfer.data
        }
        .suggestedFileName { transfer in
            transfer.filename
        }
    }
}
