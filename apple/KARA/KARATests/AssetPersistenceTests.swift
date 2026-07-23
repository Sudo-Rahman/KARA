import Foundation
import SwiftData
import Testing
@testable import KARA

@Suite("Asset persistence")
@MainActor
struct AssetPersistenceTests {
    @Test("Saving a draft persists its document and reusable suggestions together")
    func savesCompleteAssetAggregate() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let repository = SwiftDataAssetRepository(modelContext: context)
        let invoiceData = Data([0x25, 0x50, 0x44, 0x46, 0x2D])
        let draft = AssetDraft(
            name: "Bague solitaire",
            category: .jewelry,
            sellerName: "  Maison   Lémoine ",
            storageLocationName: " Coffre   personnel "
        )

        let savedAsset = try repository.save(
            draft: draft,
            attachments: [
                AssetAttachmentPayload(
                    kind: .invoice,
                    filename: "facture.pdf",
                    mimeType: "application/pdf",
                    pageCount: 1,
                    data: invoiceData
                ),
            ]
        )

        let assets = try context.fetch(FetchDescriptor<Asset>())
        let attachments = try context.fetch(FetchDescriptor<AssetAttachment>())
        let sellers = try context.fetch(FetchDescriptor<SavedSeller>())
        let locations = try context.fetch(FetchDescriptor<StorageLocation>())

        #expect(assets.count == 1)
        #expect(assets.first?.id == savedAsset.id)
        #expect(assets.first?.sellerName == "Maison Lémoine")
        #expect(attachments.count == 1)
        #expect(attachments.first?.assetID == savedAsset.id)
        #expect(attachments.first?.data == invoiceData)
        #expect(sellers.first?.normalizedName == "maison lemoine")
        #expect(locations.first?.normalizedName == "coffre personnel")
    }

    @Test("Saving an asset persists normalized inventory metadata")
    func savesNormalizedInventoryMetadata() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let repository = SwiftDataAssetRepository(modelContext: context)

        let savedAsset = try repository.save(
            draft: AssetDraft(
                name: "Lingotin 20 g",
                category: .bar,
                serialNumber: "  A12 3456 ",
                acquisitionMethod: .purchase,
                tags: [" Long   terme ", "investissement", "LONG TERME", "  "]
            ),
            attachments: []
        )

        let verificationContext = ModelContext(container)
        let persistedAsset = try #require(
            verificationContext.fetch(FetchDescriptor<Asset>()).first
        )

        #expect(persistedAsset.id == savedAsset.id)
        #expect(persistedAsset.serialNumber == "A12 3456")
        #expect(persistedAsset.acquisitionMethod == .purchase)
        #expect(persistedAsset.acquisitionMethodRawValue == "purchase")
        #expect(persistedAsset.tags == ["Long terme", "investissement"])
    }

    @Test("Updating an asset is atomic and preserves aggregate identity and documents")
    func updatesAssetWithoutReplacingItsAggregate() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let createdAt = Date(timeIntervalSince1970: 100)
        let updatedAt = Date(timeIntervalSince1970: 200)
        let repository = SwiftDataAssetRepository(modelContext: context, now: { createdAt })
        let original = try repository.save(
            draft: AssetDraft(
                name: "Lingotin",
                category: .bar,
                sellerName: "Comptoir A",
                storageLocationName: "Coffre A"
            ),
            attachments: [
                AssetAttachmentPayload(
                    kind: .certificate,
                    filename: "certificat.pdf",
                    mimeType: "application/pdf",
                    data: Data([1, 2, 3])
                ),
            ]
        )
        let originalID = original.id

        let updatingRepository = SwiftDataAssetRepository(modelContext: context, now: { updatedAt })
        let updated = try updatingRepository.update(
            assetID: originalID,
            with: AssetDraft(
                name: "Lingotin certifié",
                category: .bar,
                quantity: 2,
                sellerName: "Comptoir B",
                storageLocationName: "",
                serialNumber: "CERT-42",
                acquisitionMethod: .exchange,
                tags: ["Certifié"]
            )
        )

        #expect(updated.id == originalID)
        #expect(updated.createdAt == createdAt)
        #expect(updated.updatedAt == updatedAt)
        #expect(updated.name == "Lingotin certifié")
        #expect(updated.serialNumber == "CERT-42")
        #expect(updated.acquisitionMethod == .exchange)
        #expect(updated.tags == ["Certifié"])
        let attachments = try updatingRepository.attachments(for: originalID)
        #expect(attachments.count == 1)
        #expect(attachments.first?.data == Data([1, 2, 3]))

        let sellers = try context.fetch(FetchDescriptor<SavedSeller>())
        let locations = try context.fetch(FetchDescriptor<StorageLocation>())
        #expect(sellers.map(\.name) == ["Comptoir B"])
        #expect(sellers.first?.usageCount == 1)
        #expect(locations.isEmpty)
    }

    @Test("A failed asset update rolls back fields and reusable suggestions")
    func rollsBackFailedUpdate() throws {
        enum SimulatedFailure: Error { case save }

        let container = try makeContainer()
        let context = ModelContext(container)
        let repository = SwiftDataAssetRepository(modelContext: context)
        let original = try repository.save(
            draft: AssetDraft(
                name: "Original",
                category: .custom,
                sellerName: "Vendeur original"
            ),
            attachments: []
        )
        let failingRepository = SwiftDataAssetRepository(
            modelContext: context,
            saveAction: { _ in throw SimulatedFailure.save }
        )

        #expect(throws: SimulatedFailure.self) {
            try failingRepository.update(
                assetID: original.id,
                with: AssetDraft(
                    name: "Modifié",
                    category: .custom,
                    sellerName: "Nouveau vendeur"
                )
            )
        }

        let persistedAsset = try #require(context.fetch(FetchDescriptor<Asset>()).first)
        let sellers = try context.fetch(FetchDescriptor<SavedSeller>())
        #expect(persistedAsset.name == "Original")
        #expect(persistedAsset.sellerName == "Vendeur original")
        #expect(sellers.count == 1)
        #expect(sellers.first?.name == "Vendeur original")
        #expect(sellers.first?.usageCount == 1)
    }

    @Test("Attachments can be added and listed for one asset")
    func addsAndListsAttachmentsByAsset() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let repository = SwiftDataAssetRepository(modelContext: context)
        let asset = try repository.save(
            draft: AssetDraft(name: "Napoléon", category: .coin),
            attachments: []
        )
        let otherAsset = try repository.save(
            draft: AssetDraft(name: "Bracelet", category: .jewelry),
            attachments: []
        )

        let certificate = try repository.add(
            AssetAttachmentPayload(
                kind: .certificate,
                filename: " certificat CPOR.pdf ",
                mimeType: "application/pdf",
                data: Data([4, 2])
            ),
            to: asset.id
        )
        _ = try repository.add(
            AssetAttachmentPayload(
                kind: .other,
                filename: "expertise.pdf",
                mimeType: "application/pdf",
                data: Data([9])
            ),
            to: otherAsset.id
        )

        let attachments = try repository.attachments(for: asset.id)
        #expect(attachments.map(\.id) == [certificate.id])
        #expect(attachments.first?.kind == .certificate)
        #expect(attachments.first?.kindRawValue == "certificate")
        #expect(attachments.first?.filename == "certificat CPOR.pdf")
        #expect(AssetAttachmentKind.objectPhoto.rawValue == "objectPhoto")
        #expect(AssetAttachmentKind.invoice.rawValue == "invoice")
    }

    @Test("Attachment rename and deletion are scoped to their owning asset")
    func renamesAndDeletesAttachmentsWithinAssetScope() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let repository = SwiftDataAssetRepository(modelContext: context)
        let firstAsset = try repository.save(
            draft: AssetDraft(name: "Premier", category: .custom),
            attachments: []
        )
        let secondAsset = try repository.save(
            draft: AssetDraft(name: "Deuxième", category: .custom),
            attachments: []
        )
        let attachment = try repository.add(
            AssetAttachmentPayload(
                kind: .other,
                filename: "note.txt",
                mimeType: "text/plain",
                data: Data("note".utf8)
            ),
            to: firstAsset.id
        )

        #expect(throws: AssetRepositoryError.attachmentNotFound(attachment.id)) {
            try repository.rename(
                attachmentID: attachment.id,
                for: secondAsset.id,
                to: "intrusion.txt"
            )
        }
        let renamed = try repository.rename(
            attachmentID: attachment.id,
            for: firstAsset.id,
            to: "  note finale.txt "
        )
        #expect(renamed.filename == "note finale.txt")

        try repository.delete(attachmentID: attachment.id, for: firstAsset.id)
        #expect(try repository.attachments(for: firstAsset.id).isEmpty)
    }

    @Test("A failed attachment rename restores its persisted filename")
    func rollsBackFailedAttachmentRename() throws {
        enum SimulatedFailure: Error { case save }

        let container = try makeContainer()
        let context = ModelContext(container)
        let repository = SwiftDataAssetRepository(modelContext: context)
        let asset = try repository.save(
            draft: AssetDraft(name: "Actif", category: .custom),
            attachments: []
        )
        let attachment = try repository.add(
            AssetAttachmentPayload(
                kind: .other,
                filename: "original.txt",
                mimeType: "text/plain",
                data: Data()
            ),
            to: asset.id
        )
        let failingRepository = SwiftDataAssetRepository(
            modelContext: context,
            saveAction: { _ in throw SimulatedFailure.save }
        )

        #expect(throws: SimulatedFailure.self) {
            try failingRepository.rename(
                attachmentID: attachment.id,
                for: asset.id,
                to: "modifié.txt"
            )
        }

        #expect(try repository.attachments(for: asset.id).first?.filename == "original.txt")
    }

    @Test("A failed aggregate save rolls back and the same draft can be retried")
    func rollsBackFailedSaveAndRetries() throws {
        enum SimulatedFailure: Error { case save }

        let container = try makeContainer()
        let context = ModelContext(container)
        var saveAttempts = 0
        let repository = SwiftDataAssetRepository(
            modelContext: context,
            saveAction: { context in
                saveAttempts += 1
                guard saveAttempts > 1 else { throw SimulatedFailure.save }
                try context.save()
            }
        )
        let draft = AssetDraft(name: "Lingotin 10 g", category: .bar)

        #expect(throws: SimulatedFailure.self) {
            try repository.save(draft: draft, attachments: [])
        }
        #expect(try context.fetchCount(FetchDescriptor<Asset>()) == 0)

        let savedAsset = try repository.save(draft: draft, attachments: [])

        #expect(try context.fetchCount(FetchDescriptor<Asset>()) == 1)
        #expect(savedAsset.name == "Lingotin 10 g")
    }

    @Test("Equivalent seller and storage names reuse one suggestion and increment its counter")
    func reusesNormalizedSuggestions() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let repository = SwiftDataAssetRepository(modelContext: context)

        _ = try repository.save(
            draft: AssetDraft(
                name: "Premier actif",
                category: .custom,
                sellerName: "Maison Lémoine",
                storageLocationName: "Coffre personnel"
            ),
            attachments: []
        )
        _ = try repository.save(
            draft: AssetDraft(
                name: "Deuxième actif",
                category: .custom,
                sellerName: "  MAISON   LEMOINE ",
                storageLocationName: " coffre   PERSONNEL "
            ),
            attachments: []
        )

        let sellers = try context.fetch(FetchDescriptor<SavedSeller>())
        let locations = try context.fetch(FetchDescriptor<StorageLocation>())

        #expect(sellers.count == 1)
        #expect(sellers.first?.usageCount == 2)
        #expect(sellers.first?.normalizedName == "maison lemoine")
        #expect(locations.count == 1)
        #expect(locations.first?.usageCount == 2)
        #expect(locations.first?.normalizedName == "coffre personnel")
    }

    @Test("Moving an asset to trash preserves its aggregate and restoring reveals it again")
    func movesToTrashAndRestoresCompleteAggregate() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let deletedAt = Date(timeIntervalSince1970: 2_000)
        let repository = SwiftDataAssetRepository(modelContext: context, now: { deletedAt })
        let asset = try repository.save(
            draft: AssetDraft(name: "Napoléon", category: .coin),
            attachments: [
                AssetAttachmentPayload(
                    kind: .certificate,
                    filename: "certificat.pdf",
                    mimeType: "application/pdf",
                    data: Data([1, 2, 3])
                ),
            ]
        )

        try repository.moveToTrash(assetID: asset.id)

        #expect(asset.deletedAt == deletedAt)
        #expect(try repository.trashedAssets().map(\.id) == [asset.id])
        #expect(try repository.attachments(for: asset.id).count == 1)

        try repository.restore(assetID: asset.id)

        #expect(asset.deletedAt == nil)
        #expect(try repository.trashedAssets().isEmpty)
        #expect(try repository.attachments(for: asset.id).count == 1)
    }

    @Test("Purging removes only assets expired for 30 days and reconciles shared suggestions")
    func purgesExpiredAssetsAndTheirAttachments() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let repository = SwiftDataAssetRepository(modelContext: context)
        let expired = try repository.save(
            draft: AssetDraft(
                name: "Ancien actif",
                category: .custom,
                sellerName: "Maison Kara",
                storageLocationName: "Coffre"
            ),
            attachments: [
                AssetAttachmentPayload(
                    kind: .other,
                    filename: "ancien.txt",
                    mimeType: "text/plain",
                    data: Data([1])
                ),
            ]
        )
        let retained = try repository.save(
            draft: AssetDraft(
                name: "Actif récent",
                category: .custom,
                sellerName: "Maison Kara",
                storageLocationName: "Coffre"
            ),
            attachments: [
                AssetAttachmentPayload(
                    kind: .other,
                    filename: "recent.txt",
                    mimeType: "text/plain",
                    data: Data([2])
                ),
            ]
        )
        let cutoff = Date(timeIntervalSince1970: 10_000)
        expired.deletedAt = cutoff
        retained.deletedAt = cutoff.addingTimeInterval(1)
        try context.save()

        try repository.purgeExpiredAssets(olderThan: cutoff)

        let assets = try context.fetch(FetchDescriptor<Asset>())
        let attachments = try context.fetch(FetchDescriptor<AssetAttachment>())
        let seller = try #require(context.fetch(FetchDescriptor<SavedSeller>()).first)
        let location = try #require(context.fetch(FetchDescriptor<StorageLocation>()).first)
        #expect(assets.map(\.id) == [retained.id])
        #expect(attachments.count == 1)
        #expect(attachments.first?.assetID == retained.id)
        #expect(seller.usageCount == 1)
        #expect(location.usageCount == 1)
    }

    @Test("A failed trash move leaves the asset active")
    func rollsBackFailedTrashMove() throws {
        enum SimulatedFailure: Error { case save }

        let container = try makeContainer()
        let context = ModelContext(container)
        let repository = SwiftDataAssetRepository(modelContext: context)
        let asset = try repository.save(
            draft: AssetDraft(name: "Actif", category: .custom),
            attachments: []
        )
        let failingRepository = SwiftDataAssetRepository(
            modelContext: context,
            now: { Date(timeIntervalSince1970: 3_000) },
            saveAction: { _ in throw SimulatedFailure.save }
        )

        #expect(throws: SimulatedFailure.self) {
            try failingRepository.moveToTrash(assetID: asset.id)
        }

        let verificationContext = ModelContext(container)
        let persistedAsset = try #require(
            verificationContext.fetch(FetchDescriptor<Asset>()).first
        )
        #expect(persistedAsset.deletedAt == nil)
    }

    @Test("A failed purge restores the asset, its attachment and reusable suggestions")
    func rollsBackFailedPurge() throws {
        enum SimulatedFailure: Error { case save }

        let container = try makeContainer()
        let context = ModelContext(container)
        let repository = SwiftDataAssetRepository(modelContext: context)
        let asset = try repository.save(
            draft: AssetDraft(
                name: "Actif expiré",
                category: .custom,
                sellerName: "Maison Kara",
                storageLocationName: "Coffre"
            ),
            attachments: [
                AssetAttachmentPayload(
                    kind: .other,
                    filename: "preuve.txt",
                    mimeType: "text/plain",
                    data: Data([1])
                ),
            ]
        )
        let cutoff = Date(timeIntervalSince1970: 10_000)
        asset.deletedAt = cutoff
        try context.save()
        let failingRepository = SwiftDataAssetRepository(
            modelContext: context,
            saveAction: { _ in throw SimulatedFailure.save }
        )

        #expect(throws: SimulatedFailure.self) {
            try failingRepository.purgeExpiredAssets(olderThan: cutoff)
        }

        let verificationContext = ModelContext(container)
        #expect(try verificationContext.fetchCount(FetchDescriptor<Asset>()) == 1)
        #expect(try verificationContext.fetchCount(FetchDescriptor<AssetAttachment>()) == 1)
        #expect(try verificationContext.fetchCount(FetchDescriptor<SavedSeller>()) == 1)
        #expect(try verificationContext.fetchCount(FetchDescriptor<StorageLocation>()) == 1)
    }

    @Test("The retention cutoff uses 30 calendar days")
    func computesCalendarRetentionCutoff() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/Paris"))
        let asOf = try #require(calendar.date(from: DateComponents(
            year: 2026,
            month: 4,
            day: 15,
            hour: 12
        )))

        let cutoff = AssetTrashPolicy.expirationCutoff(asOf: asOf, calendar: calendar)
        let components = calendar.dateComponents([.year, .month, .day, .hour], from: cutoff)

        #expect(components.year == 2026)
        #expect(components.month == 3)
        #expect(components.day == 16)
        #expect(components.hour == 12)
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            Asset.self,
            AssetAttachment.self,
            SavedSeller.self,
            StorageLocation.self,
        ])
        let configuration = ModelConfiguration(
            "AssetPersistenceTests",
            schema: schema,
            isStoredInMemoryOnly: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
