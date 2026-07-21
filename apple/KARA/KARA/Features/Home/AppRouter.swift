import Foundation
import Observation

enum AppRoute: Hashable {
    case inventory
    case assetDetail(UUID)
    case assetDocuments(UUID)
}

enum AppSheetDestination: Hashable, Identifiable {
    case editAsset(UUID)
    case saleSimulation

    var id: String {
        switch self {
        case let .editAsset(assetID):
            "edit-asset-\(assetID.uuidString)"
        case .saleSimulation:
            "sale-simulation"
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

    init(
        path: [AppRoute] = [],
        sheet: AppSheetDestination? = nil,
        cover: AppCoverDestination? = nil
    ) {
        self.path = path
        self.sheet = sheet
        self.cover = cover
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

    func presentSaleSimulation() {
        sheet = .saleSimulation
    }

    func presentAssetCreation() {
        cover = .assetCreation
    }
}
