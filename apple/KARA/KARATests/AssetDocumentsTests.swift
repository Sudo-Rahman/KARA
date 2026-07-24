import Foundation
import Testing
@testable import KARA

@Suite("Asset documents")
@MainActor
struct AssetDocumentsTests {
    @Test("Filters only expose document kinds that exist on the selected asset")
    func derivesUsefulFilters() {
        let assetID = UUID()
        let attachments = [
            AssetAttachment(assetID: assetID, kind: .objectPhoto),
            AssetAttachment(assetID: assetID, kind: .certificate),
            AssetAttachment(assetID: assetID, kind: .certificate),
        ]

        #expect(AssetDocumentFilter.options(for: attachments) == [
            .all,
            .kind(.objectPhoto),
            .kind(.certificate),
        ])
    }

    @Test("Temporary preview filenames cannot escape their private directory")
    func sanitizesPreviewFilename() {
        #expect(AssetAttachmentFileName.safeComponent("../../secret.pdf") == "secret.pdf")
        #expect(AssetAttachmentFileName.safeComponent("  certificat\nfinal.pdf ") == "certificat final.pdf")
        #expect(AssetAttachmentFileName.safeComponent("..") == "document")
    }

    @Test("Document names hide their extension and preserve it when renamed")
    func presentsAndRenamesFilenameWithoutExtension() {
        #expect(AssetAttachmentFileName.displayName("facture.pdf") == "facture")
        #expect(AssetAttachmentFileName.displayName("archive.tar.gz") == "archive.tar")
        #expect(AssetAttachmentFileName.displayName("photo") == "photo")

        #expect(
            AssetAttachmentFileName.replacingDisplayName(
                in: "facture.pdf",
                with: "Facture finale"
            ) == "Facture finale.pdf"
        )
        #expect(
            AssetAttachmentFileName.replacingDisplayName(
                in: "archive.tar.gz",
                with: "sauvegarde"
            ) == "sauvegarde.gz"
        )
        #expect(
            AssetAttachmentFileName.replacingDisplayName(
                in: "photo",
                with: "Objet"
            ) == "Objet"
        )
    }

    @Test("Every document category has English and French copy in its dedicated table")
    func localizesDocumentCategories() throws {
        let requiredKeys = AssetAttachmentKind.allCases.map {
            "documents.kind.\($0.rawValue)"
        } + ["documents.title", "documents.empty.title", "documents.error.title"]

        for language in ["en", "fr"] {
            let url = try #require(Bundle.main.url(
                forResource: "AssetDocuments",
                withExtension: "strings",
                subdirectory: nil,
                localization: language
            ))
            let data = try Data(contentsOf: url)
            let strings = try #require(
                PropertyListSerialization.propertyList(from: data, format: nil)
                    as? [String: String]
            )
            for key in requiredKeys {
                #expect(strings[key] != nil, "Missing \(language) localization for \(key)")
            }
        }
    }
}
