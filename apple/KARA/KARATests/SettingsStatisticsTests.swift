import Foundation
import Testing
@testable import KARA

@Suite("Settings statistics")
@MainActor
struct SettingsStatisticsTests {
    @Test("Vault statistics distinguish assets, objects, documents and photos")
    func summarizesVaultContentsAndTrash() {
        let firstAsset = Asset(
            name: "Lingot",
            category: .bar,
            quantity: 1
        )
        let secondAsset = Asset(
            name: "Napoleons",
            category: .coin,
            quantity: 4
        )
        let attachments = [
            AssetAttachment(
                assetID: firstAsset.id,
                kind: .objectPhoto,
                filename: "lingot.jpg",
                mimeType: "image/jpeg",
                data: Data(repeating: 0x01, count: 3)
            ),
            AssetAttachment(
                assetID: firstAsset.id,
                kind: .invoice,
                filename: "facture.pdf",
                mimeType: "application/pdf",
                data: Data(repeating: 0x02, count: 5)
            ),
            AssetAttachment(
                assetID: secondAsset.id,
                kind: .certificate,
                filename: "certificat.pdf",
                mimeType: "application/pdf",
                data: Data(repeating: 0x03, count: 7)
            ),
        ]

        let statistics = SettingsStatistics(
            activeAssets: [firstAsset, secondAsset],
            activeAttachments: attachments,
            trashedAssetCount: 2
        )

        #expect(statistics.activeAssetCount == 2)
        #expect(statistics.objectCount == 5)
        #expect(statistics.documentCount == 2)
        #expect(statistics.photoCount == 1)
        #expect(statistics.attachmentCount == 3)
        #expect(statistics.attachmentByteCount == 15)
        #expect(statistics.trashedAssetCount == 2)
    }

    @Test("Vault storage remains unknown for attachments created before byte metadata")
    func leavesLegacyAttachmentStorageUnknown() {
        let asset = Asset(name: "Lingot", category: .bar)
        let legacyAttachment = AssetAttachment(
            assetID: asset.id,
            kind: .invoice,
            filename: "facture.pdf",
            mimeType: "application/pdf",
            data: Data(repeating: 0x01, count: 1_024)
        )
        legacyAttachment.dataByteCount = nil

        let statistics = SettingsStatistics(
            activeAssets: [asset],
            activeAttachments: [legacyAttachment],
            trashedAssetCount: 0
        )

        #expect(statistics.attachmentByteCount == nil)
    }

    @Test("App version combines the marketing version and build number")
    func formatsVersionAndBuild() {
        let versionInfo = AppVersionInfo(infoDictionary: [
            "CFBundleShortVersionString": "2.4.1",
            "CFBundleVersion": "128",
        ])

        #expect(versionInfo.version == "2.4.1")
        #expect(versionInfo.build == "128")
        #expect(versionInfo.displayName == "2.4.1 (128)")
    }

    @Test("App version falls back gracefully when bundle metadata is absent")
    func handlesMissingVersionAndBuild() {
        let versionInfo = AppVersionInfo(infoDictionary: [:])

        #expect(versionInfo.version == "—")
        #expect(versionInfo.build == "—")
        #expect(versionInfo.displayName == "—")
    }

    @Test("App version remains readable when only the build number is absent")
    func handlesMissingBuild() {
        let versionInfo = AppVersionInfo(infoDictionary: [
            "CFBundleShortVersionString": "2.4.1",
        ])

        #expect(versionInfo.version == "2.4.1")
        #expect(versionInfo.build == "—")
        #expect(versionInfo.displayName == "2.4.1")
    }
}
