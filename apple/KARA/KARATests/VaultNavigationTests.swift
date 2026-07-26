import Foundation
import Testing
@testable import KARA

@Suite("Vault navigation")
@MainActor
struct VaultNavigationTests {
    @Test("The app exposes three stable top-level tabs in product order")
    func exposesTopLevelTabs() {
        #expect(AppTab.allCases == [.vault, .sale, .settings])
        #expect(Set(AppTab.allCases.map(\.id)).count == AppTab.allCases.count)
    }

    @Test("The vault router keeps detail and editing destinations contextual")
    func routesInventoryAssetDocumentsAndEditing() {
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

        router.presentAssetCreation()
        #expect(router.cover == .assetCreation)

        router.dismissCurrentRoute()
        #expect(router.path == [
            .inventory,
            .assetDetail(assetID),
        ])
    }
}
