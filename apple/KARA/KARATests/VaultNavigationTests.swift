import Foundation
import Testing
@testable import KARA

@Suite("Vault navigation")
@MainActor
struct VaultNavigationTests {
    @Test("The vault router keeps pushed and modal destinations contextual")
    func routesInventoryAssetDocumentsAndModals() {
        let assetID = UUID()
        let router = AppRouter()

        router.showInventory()
        router.showAsset(assetID)
        router.showDocuments(for: assetID)

        #expect(router.path == [
            .inventory,
            .assetDetail(assetID),
            .assetDocuments(assetID),
        ])

        router.presentEditor(for: assetID)
        #expect(router.sheet == .editAsset(assetID))

        router.presentSaleSimulation()
        #expect(router.sheet == .saleSimulation)

        router.presentAssetCreation()
        #expect(router.cover == .assetCreation)

        router.dismissCurrentRoute()
        #expect(router.path == [
            .inventory,
            .assetDetail(assetID),
        ])
    }
}
