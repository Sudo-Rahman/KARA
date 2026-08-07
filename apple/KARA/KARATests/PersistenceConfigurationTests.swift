import PDFKit
import SwiftData
import Testing
import UIKit
@testable import KARA

@Suite("Persistence configuration")
@MainActor
struct PersistenceConfigurationTests {
    @Test("Debug uses a persistent local store without CloudKit")
    func debugConfigurationUsesIsolatedLocalStore() {
        let configuration = KaraModelContainerFactory.configuration(
            arguments: [],
            environment: [:]
        )

        #expect(!configuration.isStoredInMemoryOnly)
        #expect(configuration.cloudKitContainerIdentifier == nil)
        #expect(KaraWidgetSnapshotStore.defaultAppGroupIdentifier == "group.karaprivate.kara.dev")
    }

    #if DEBUG
    @Test("The explicit DEBUG launch argument isolates tests in memory")
    func debugConfigurationCanUseMemory() {
        let configuration = KaraModelContainerFactory.configuration(
            arguments: ["-KARAUseInMemoryStore"],
            environment: [:]
        )

        #expect(configuration.isStoredInMemoryOnly)
        #expect(configuration.cloudKitContainerIdentifier == nil)
    }

    @Test("A unit-test host never opens CloudKit")
    func unitTestHostUsesMemory() {
        let configuration = KaraModelContainerFactory.configuration(
            arguments: [],
            environment: ["XCTestConfigurationFilePath": "/tmp/KARA.xctestconfiguration"]
        )

        #expect(configuration.isStoredInMemoryOnly)
        #expect(configuration.cloudKitContainerIdentifier == nil)
    }

    @Test("The explicit visual QA launch arguments seed a realistic linked vault")
    func visualQAArgumentsSeedLinkedVault() throws {
        let container = try KaraModelContainerFactory.make(
            arguments: [
                KaraModelContainerFactory.inMemoryLaunchArgument,
                VisualQAVaultSeeder.launchArgument,
            ],
            environment: [:]
        )
        let context = ModelContext(container)
        let assets = try context.fetch(FetchDescriptor<Asset>())
        let attachments = try context.fetch(FetchDescriptor<AssetAttachment>())

        #expect(assets.count >= 4)
        #expect(Set(assets.compactMap(\.metal)).isSuperset(of: [.gold, .silver]))
        #expect(assets.contains { $0.category == .bar })
        #expect(assets.contains { $0.category == .coin })
        #expect(assets.contains { $0.category == .jewelry })
        #expect(!attachments.isEmpty)
        #expect(attachments.contains { $0.kind == .objectPhoto && !$0.data.isEmpty })
        #expect(attachments.allSatisfy { attachment in
            assets.contains { $0.id == attachment.assetID }
        })

        let invoice = try #require(attachments.first { $0.kind == .invoice })
        let invoicePDF = try #require(PDFDocument(data: invoice.data))
        #expect(invoice.filename.lowercased().hasSuffix(".pdf"))
        #expect(invoice.mimeType == "application/pdf")
        #expect(invoice.pageCount == invoicePDF.pageCount)
        #expect(invoicePDF.pageCount == 1)

        let certificate = try #require(attachments.first { $0.kind == .certificate })
        #expect(certificate.filename.lowercased().hasSuffix(".jpg"))
        #expect(certificate.mimeType == "image/jpeg")
        #expect(certificate.pageCount == 1)
        #expect(UIImage(data: certificate.data) != nil)
    }

    @Test("Visual QA seed requires both explicit DEBUG launch arguments")
    func visualQASeedRequiresBothArguments() throws {
        for arguments in [
            [KaraModelContainerFactory.inMemoryLaunchArgument],
            [VisualQAVaultSeeder.launchArgument],
        ] {
            let container = try KaraModelContainerFactory.make(
                arguments: arguments,
                environment: [
                    "XCTestConfigurationFilePath": "/tmp/KARA.xctestconfiguration",
                ]
            )
            let context = ModelContext(container)

            #expect(try context.fetchCount(FetchDescriptor<Asset>()) == 0)
            #expect(try context.fetchCount(FetchDescriptor<AssetAttachment>()) == 0)
        }
    }

    @Test("Visual QA seed preserves a nonempty vault")
    func visualQASeedPreservesExistingVault() throws {
        let container = try KaraModelContainerFactory.make(
            arguments: [KaraModelContainerFactory.inMemoryLaunchArgument],
            environment: [:]
        )
        let context = ModelContext(container)
        let existingAsset = Asset(name: "Actif existant", category: .custom)
        context.insert(existingAsset)
        try context.save()

        try VisualQAVaultSeeder.seedIfRequested(
            in: container,
            arguments: [
                KaraModelContainerFactory.inMemoryLaunchArgument,
                VisualQAVaultSeeder.launchArgument,
            ]
        )

        let assets = try context.fetch(FetchDescriptor<Asset>())
        #expect(assets.count == 1)
        #expect(assets.first?.id == existingAsset.id)
        #expect(try context.fetchCount(FetchDescriptor<AssetAttachment>()) == 0)
    }
    #endif
}
