import Foundation
import SwiftUI
import UIKit

nonisolated struct VaultReportShareItem: Identifiable, Sendable {
    let id = UUID()
    let url: URL
}

nonisolated enum TemporaryVaultReportFileStore {
    static func write(transfer: VaultReportTransfer) throws -> VaultReportShareItem {
        let manager = FileManager.default
        let root = rootDirectory(using: manager)
        let directory = root
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try manager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        let filename = (transfer.filename as NSString).lastPathComponent
        let url = directory.appending(path: filename, directoryHint: .notDirectory)

        do {
            try transfer.data.write(to: url, options: [.atomic, .completeFileProtection])
            return VaultReportShareItem(url: url)
        } catch {
            try? manager.removeItem(at: directory)
            throw error
        }
    }

    static func remove(_ item: VaultReportShareItem) {
        removeFile(at: item.url)
    }

    static func removeFile(at url: URL) {
        try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
    }

    static func purgeStaleReports() {
        try? FileManager.default.removeItem(
            at: rootDirectory(using: .default)
        )
    }

    private static func rootDirectory(using manager: FileManager) -> URL {
        manager.temporaryDirectory
            .appending(path: "KARA-Vault-Reports", directoryHint: .isDirectory)
    }
}

struct VaultReportActivityView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        controller.view.accessibilityIdentifier = "settings.vault.report.share-sheet"
        return controller
    }

    func updateUIViewController(
        _: UIActivityViewController,
        context _: Context
    ) {}
}
