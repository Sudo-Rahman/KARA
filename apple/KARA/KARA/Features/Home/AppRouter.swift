import Foundation
import Observation

nonisolated enum AppTab: String, CaseIterable, Identifiable, Sendable {
    case vault
    case analysis
    case sale
    case settings

    var id: Self { self }
}

enum AppRoute: Hashable {
    case inventory
    case assetDetail(UUID)
    case assetDocuments(UUID)
}

enum AppSheetDestination: Hashable, Identifiable {
    case editAsset(UUID)

    var id: String {
        switch self {
        case let .editAsset(assetID):
            "edit-asset-\(assetID.uuidString)"
        }
    }
}

enum AppCoverDestination: Hashable, Identifiable {
    case assetCreation

    var id: String { "asset-creation" }
}

@MainActor
@Observable
final class AppRouter {
    var path: [AppRoute]
    var sheet: AppSheetDestination?
    var cover: AppCoverDestination?
    var selectedTab: AppTab
    var salesPath: [SalesRoute]

    init(
        path: [AppRoute] = [],
        sheet: AppSheetDestination? = nil,
        cover: AppCoverDestination? = nil,
        selectedTab: AppTab = .vault,
        salesPath: [SalesRoute] = []
    ) {
        self.path = path
        self.sheet = sheet
        self.cover = cover
        self.selectedTab = selectedTab
        self.salesPath = salesPath
    }

    func showInventory() {
        path.append(.inventory)
    }

    func showAsset(_ assetID: UUID) {
        path.append(.assetDetail(assetID))
    }

    func showDocuments(for assetID: UUID) {
        path.append(.assetDocuments(assetID))
    }

    func presentEditor(for assetID: UUID) {
        sheet = .editAsset(assetID)
    }

    func presentAssetCreation() {
        cover = .assetCreation
    }

    func dismissCurrentRoute() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func showPriceAlertFromNotification(
        _ request: PriceAlertNotificationNavigationRequest,
        availableAlertIDs: Set<UUID>
    ) {
        selectedTab = .sale
        salesPath = availableAlertIDs.contains(request.alertID)
            ? [.alert(request.alertID)]
            : [.alerts]
    }
}
