import Foundation
import Testing
@testable import KARA

@Suite("Vault navigation")
@MainActor
struct VaultNavigationTests {
    @Test("The app exposes four stable top-level tabs in product order")
    func exposesTopLevelTabs() {
        #expect(AppTab.allCases == [.vault, .analysis, .sale, .settings])
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

    @Test("A notification opens its alert in the Sales tab when it still exists")
    func routesExistingPriceAlertNotification() {
        let alertID = UUID()
        let request = PriceAlertNotificationNavigationRequest(
            alertID: alertID,
            assetID: UUID()
        )
        let router = AppRouter()

        router.showPriceAlertFromNotification(
            request,
            availableAlertIDs: [alertID]
        )

        #expect(router.selectedTab == .sale)
        #expect(router.salesPath == [.alert(alertID)])
    }

    @Test("A notification falls back to the alert list when its alert is gone")
    func routesMissingPriceAlertNotification() {
        let request = PriceAlertNotificationNavigationRequest(
            alertID: UUID(),
            assetID: UUID()
        )
        let router = AppRouter(
            selectedTab: .analysis,
            salesPath: [.history]
        )

        router.showPriceAlertFromNotification(
            request,
            availableAlertIDs: []
        )

        #expect(router.selectedTab == .sale)
        #expect(router.salesPath == [.alerts])
    }
}
