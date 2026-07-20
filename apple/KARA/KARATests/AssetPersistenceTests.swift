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
