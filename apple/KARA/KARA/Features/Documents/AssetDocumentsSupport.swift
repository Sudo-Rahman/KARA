import CoreTransferable
import Foundation
import QuickLook
import SwiftUI
import UIKit
import UniformTypeIdentifiers

enum AssetDocumentFilter: Hashable, Identifiable {
    case all
    case kind(AssetAttachmentKind)

    var id: String {
        switch self {
        case .all: "all"
        case let .kind(kind): kind.rawValue
        }
    }

    static func options(for attachments: [AssetAttachment]) -> [Self] {
        let existingKinds = Set(attachments.map(\.kind))
        return [.all] + AssetAttachmentKind.allCases.compactMap { kind in
            existingKinds.contains(kind) ? .kind(kind) : nil
        }
    }

    func includes(_ attachment: AssetAttachment) -> Bool {
        switch self {
        case .all: true
        case let .kind(kind): attachment.kind == kind
        }
    }
}

nonisolated enum AssetAttachmentContentKind: Equatable, Sendable {
    case pdf
    case image
    case text
    case file

    init(mimeType: String) {
        let normalized = mimeType.lowercased()
        if normalized == "application/pdf" {
            self = .pdf
        } else if normalized.hasPrefix("image/") {
            self = .image
        } else if normalized.hasPrefix("text/")
                    || normalized == "application/json"
                    || normalized.hasSuffix("+json")
                    || normalized == "application/xml"
                    || normalized.hasSuffix("+xml") {
            self = .text
        } else {
            self = .file
        }
    }

    var localizationKey: String {
        switch self {
        case .pdf: "documents.metadata.pdf"
        case .image: "documents.metadata.image"
        case .text: "documents.metadata.text"
        case .file: "documents.metadata.file"
        }
    }
}

nonisolated enum AssetAttachmentFileName {
    static func safeComponent(_ filename: String) -> String {
        let lastComponent = (filename as NSString).lastPathComponent
        let withoutControls = lastComponent
            .components(separatedBy: .controlCharacters)
            .joined(separator: " ")
        let collapsed = withoutControls
            .split(whereSeparator: \Character.isWhitespace)
            .joined(separator: " ")
        guard !collapsed.isEmpty, collapsed != ".", collapsed != ".." else {
            return "document"
        }
        return String(collapsed.prefix(180))
    }
}

struct AttachmentPreviewItem: Identifiable {
    let id: UUID
    let title: String
    let url: URL
}

struct AttachmentPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: AttachmentPreviewItem

    var body: some View {
        NavigationStack {
            AttachmentQuickLookView(url: item.url)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(AssetDocumentsCopy.string("documents.close")) { dismiss() }
                    }
                }
        }
    }
}

private struct AttachmentQuickLookView: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        context.coordinator.url = url
        controller.reloadData()
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in _: QLPreviewController) -> Int { 1 }

        func previewController(
            _: QLPreviewController,
            previewItemAt _: Int
        ) -> any QLPreviewItem {
            url as NSURL
        }
    }
}

nonisolated struct AssetAttachmentTransfer: Transferable, Sendable {
    let data: Data
    let filename: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .data) { item in
            item.data
        }
        .suggestedFileName { item in
            AssetAttachmentFileName.safeComponent(item.filename)
        }
    }
}

/// A document-camera page is an immutable snapshot for the lifetime of scan preparation.
/// This wrapper keeps the single unchecked boundary explicit instead of sending UIKit
/// objects through the view's main-actor task directly.
nonisolated struct ScannedDocumentPage: @unchecked Sendable {
    let image: UIImage

    init(_ image: UIImage) {
        self.image = image
    }
}

nonisolated enum ScannedDocumentPreparation {
    static func prepare(
        pages: [ScannedDocumentPage],
        filename: String
    ) async throws -> PreparedMediaDocument {
        try await Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            return try MediaDocumentFactory.invoicePDF(
                from: pages.map(\.image),
                filename: filename
            )
        }.value
    }
}

nonisolated enum TemporaryAttachmentFileStore {
    static func write(data: Data, filename: String, mimeType: String) throws -> URL {
        let manager = FileManager.default
        let root = manager.temporaryDirectory
            .appending(path: "KARA-Attachment-Previews", directoryHint: .isDirectory)
        let directory = root.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try manager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        var component = AssetAttachmentFileName.safeComponent(filename)
        if (component as NSString).pathExtension.isEmpty,
           let fileExtension = UTType(mimeType: mimeType)?.preferredFilenameExtension {
            component += ".\(fileExtension)"
        }
        let url = directory.appending(path: component, directoryHint: .notDirectory)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    static func removeFile(at url: URL) {
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: directory)
    }
}

enum AssetDocumentsCopy {
    static func string(_ key: String) -> String {
        NSLocalizedString(
            key,
            tableName: "AssetDocuments",
            bundle: .main,
            value: key,
            comment: ""
        )
    }
}

extension AssetAttachmentKind {
    var documentsLocalizationKey: String {
        "documents.kind.\(rawValue)"
    }

    var documentsSymbolName: String {
        switch self {
        case .objectPhoto: "photo.fill"
        case .invoice: "doc.text.fill"
        case .certificate: "checkmark.seal.fill"
        case .other: "doc.fill"
        }
    }
}
