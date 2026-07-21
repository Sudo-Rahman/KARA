import Foundation
import Testing
import UIKit
@testable import KARA

@Suite("Apple asset intelligence routing")
@MainActor
struct AssetIntelligenceTests {
    @Test
    func availableOnDeviceModelHandlesPhotoWithoutCallingCloud() async throws {
        let analyzer = RecordingAssetModelAnalyzer(
            outcomes: [.onDevice: .success(AssetAnalysisSuggestion(name: "Lingotin"))]
        )
        let service = AppleAssetAnalysisService(
            availabilityChecker: StaticAssetModelAvailabilityChecker(
                availability: AssetModelAvailability(
                    onDevice: .ready,
                    privateCloudCompute: .ready
                )
            ),
            modelAnalyzer: analyzer,
            locale: Locale(identifier: "fr_FR")
        )

        let suggestion = try await service.analyzeObjectPhoto(makeJPEG())

        #expect(suggestion.name == "Lingotin")
        #expect(await analyzer.recordedRoutes() == [.onDevice])
    }

    @Test
    func unavailableOnDeviceModelUsesPrivateCloudCompute() async throws {
        let analyzer = RecordingAssetModelAnalyzer(
            outcomes: [
                .privateCloudCompute: .success(
                    AssetAnalysisSuggestion(name: "Napoléon")
                ),
            ]
        )
        let service = AppleAssetAnalysisService(
            availabilityChecker: StaticAssetModelAvailabilityChecker(
                availability: AssetModelAvailability(
                    onDevice: .unavailable,
                    privateCloudCompute: .ready
                )
            ),
            modelAnalyzer: analyzer,
            locale: Locale(identifier: "fr_FR")
        )

        let suggestion = try await service.analyzeObjectPhoto(makeJPEG())

        #expect(suggestion.name == "Napoléon")
        #expect(await analyzer.recordedRoutes() == [.privateCloudCompute])
    }

    @Test
    func technicalOnDeviceFailureRetriesWithPrivateCloudCompute() async throws {
        let analyzer = RecordingAssetModelAnalyzer(
            outcomes: [
                .onDevice: .failure(.technicalFailure),
                .privateCloudCompute: .success(
                    AssetAnalysisSuggestion(name: "Britannia")
                ),
            ]
        )
        let service = AppleAssetAnalysisService(
            availabilityChecker: StaticAssetModelAvailabilityChecker(
                availability: AssetModelAvailability(
                    onDevice: .ready,
                    privateCloudCompute: .ready
                )
            ),
            modelAnalyzer: analyzer,
            locale: Locale(identifier: "fr_FR")
        )

        let suggestion = try await service.analyzeObjectPhoto(makeJPEG())

        #expect(suggestion.name == "Britannia")
        #expect(await analyzer.recordedRoutes() == [.onDevice, .privateCloudCompute])
    }

    @Test
    func modelRefusalDoesNotRetryInPrivateCloudCompute() async throws {
        let analyzer = RecordingAssetModelAnalyzer(
            outcomes: [.onDevice: .failure(.refused)]
        )
        let service = AppleAssetAnalysisService(
            availabilityChecker: StaticAssetModelAvailabilityChecker(
                availability: AssetModelAvailability(
                    onDevice: .ready,
                    privateCloudCompute: .ready
                )
            ),
            modelAnalyzer: analyzer,
            locale: Locale(identifier: "fr_FR")
        )

        await #expect(throws: AssetAnalysisError.refused) {
            try await service.analyzeObjectPhoto(makeJPEG())
        }
        #expect(await analyzer.recordedRoutes() == [.onDevice])
    }

    @Test
    func cancellationDoesNotRetryInPrivateCloudCompute() async throws {
        let analyzer = RecordingAssetModelAnalyzer(
            outcomes: [.onDevice: .failure(.cancelled)]
        )
        let service = AppleAssetAnalysisService(
            availabilityChecker: StaticAssetModelAvailabilityChecker(
                availability: AssetModelAvailability(
                    onDevice: .ready,
                    privateCloudCompute: .ready
                )
            ),
            modelAnalyzer: analyzer,
            locale: Locale(identifier: "fr_FR")
        )

        await #expect(throws: CancellationError.self) {
            try await service.analyzeObjectPhoto(makeJPEG())
        }
        #expect(await analyzer.recordedRoutes() == [.onDevice])
    }

    @Test
    func invalidPhotoStopsBeforeCallingAnyModel() async {
        let analyzer = RecordingAssetModelAnalyzer(outcomes: [:])
        let service = AppleAssetAnalysisService(
            availabilityChecker: StaticAssetModelAvailabilityChecker(
                availability: AssetModelAvailability(
                    onDevice: .ready,
                    privateCloudCompute: .ready
                )
            ),
            modelAnalyzer: analyzer,
            locale: Locale(identifier: "fr_FR")
        )

        await #expect(throws: AssetAnalysisError.invalidInput) {
            try await service.analyzeObjectPhoto(Data("not-an-image".utf8))
        }
        #expect(await analyzer.recordedRoutes().isEmpty)
    }

    @Test
    func unreadableInvoiceStopsBeforeCallingAnyModel() async {
        let analyzer = RecordingAssetModelAnalyzer(outcomes: [:])
        let service = AppleAssetAnalysisService(
            availabilityChecker: StaticAssetModelAvailabilityChecker(
                availability: AssetModelAvailability(
                    onDevice: .ready,
                    privateCloudCompute: .ready
                )
            ),
            modelAnalyzer: analyzer,
            locale: Locale(identifier: "fr_FR")
        )

        await #expect(throws: AssetAnalysisError.invalidInput) {
            try await service.analyzeInvoice(
                Data("not-a-pdf".utf8),
                filename: "facture.pdf",
                mimeType: "application/pdf"
            )
        }
        #expect(await analyzer.recordedRoutes().isEmpty)
    }

    @Test
    func unavailableModelsReturnManualFallbackWithoutCallingAnalyzer() async throws {
        let analyzer = RecordingAssetModelAnalyzer(outcomes: [:])
        let service = AppleAssetAnalysisService(
            availabilityChecker: StaticAssetModelAvailabilityChecker(
                availability: AssetModelAvailability(
                    onDevice: .unavailable,
                    privateCloudCompute: .unavailable
                )
            ),
            modelAnalyzer: analyzer,
            locale: Locale(identifier: "fr_FR")
        )

        await #expect(throws: AssetAnalysisError.unavailable) {
            try await service.analyzeObjectPhoto(makeJPEG())
        }
        #expect(await analyzer.recordedRoutes().isEmpty)
    }

    @Test
    func generatedFieldsAreValidatedBeforeBecomingSuggestions() throws {
        let amount = try #require(Decimal(string: "2390.005"))
        let generated = GeneratedAssetAnalysis(
            name: "  Lingotin   10 g ",
            category: "bar",
            presetID: "gold-bar-10g",
            quantity: 0,
            purchaseDateISO8601: "2024-05-14",
            metal: "gold",
            weightGrams: .nan,
            metalKarat: 25,
            finenessPermille: 999.9,
            gemstoneCaratWeight: -1,
            gemstoneClarity: " ",
            pricePaidAmount: amount,
            currencyCode: " eur ",
            sellerName: "  Maison   Lemoine ",
            storageLocationName: " ",
            invoiceNumber: " ML2024-05872 ",
            serialNumber: " A12 3456 ",
            acquisitionMethod: "purchase",
            tags: [" investissement ", "Long   terme", "INVESTISSEMENT"]
        )

        let suggestion = FoundationModelAssetAnalyzer.suggestion(from: generated)

        #expect(suggestion.name == "Lingotin 10 g")
        #expect(suggestion.category == .bar)
        #expect(suggestion.presetID == "gold-bar-10g")
        #expect(suggestion.quantity == nil)
        #expect(suggestion.metal == .gold)
        #expect(suggestion.weightGrams == nil)
        #expect(suggestion.metalKarat == nil)
        #expect(suggestion.finenessPermille == 999.9)
        #expect(suggestion.gemstoneCaratWeight == nil)
        #expect(suggestion.gemstoneClarity == nil)
        #expect(suggestion.pricePaidMinorUnits == 239_001)
        #expect(suggestion.currencyCode == "EUR")
        #expect(suggestion.sellerName == "Maison Lemoine")
        #expect(suggestion.storageLocationName == nil)
        #expect(suggestion.invoiceNumber == "ML2024-05872")
        #expect(suggestion.serialNumber == "A12 3456")
        #expect(suggestion.acquisitionMethod == .purchase)
        #expect(suggestion.tags == ["investissement", "Long terme"])

        let calendar = Calendar(identifier: .gregorian)
        let components = suggestion.purchaseDate.map {
            calendar.dateComponents([.year, .month, .day], from: $0)
        }
        #expect(components?.year == 2024)
        #expect(components?.month == 5)
        #expect(components?.day == 14)
    }

    @Test
    func generatedFieldsAcceptLegacyCategoriesButRejectUnsupportedPurchaseCurrencies() throws {
        let generated = GeneratedAssetAnalysis(
            category: "goldCoin",
            pricePaidAmount: Decimal(2_000),
            currencyCode: "JPY"
        )

        let suggestion = FoundationModelAssetAnalyzer.suggestion(from: generated)

        #expect(suggestion.category == .coin)
        #expect(suggestion.currencyCode == nil)
        #expect(suggestion.pricePaidMinorUnits == nil)
    }

    private func makeJPEG() throws -> Data {
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: 40, height: 40)
        ).image { context in
            UIColor.systemYellow.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
        return try #require(image.jpegData(compressionQuality: 0.8))
    }
}

private actor RecordingAssetModelAnalyzer: AssetModelAnalyzing {
    nonisolated enum Outcome: Sendable {
        case success(AssetAnalysisSuggestion)
        case failure(AssetAnalysisError)
    }

    private let outcomes: [AssetIntelligenceModelRoute: Outcome]
    private(set) var routes: [AssetIntelligenceModelRoute] = []

    init(outcomes: [AssetIntelligenceModelRoute: Outcome]) {
        self.outcomes = outcomes
    }

    func analyze(
        _ input: AssetModelAnalysisInput,
        using route: AssetIntelligenceModelRoute
    ) async throws -> AssetAnalysisSuggestion {
        routes.append(route)
        switch outcomes[route] ?? .failure(.technicalFailure) {
        case let .success(suggestion):
            return suggestion
        case let .failure(error):
            throw error
        }
    }

    func recordedRoutes() -> [AssetIntelligenceModelRoute] {
        routes
    }
}

private nonisolated struct StaticAssetModelAvailabilityChecker: AssetModelAvailabilityChecking {
    let availability: AssetModelAvailability

    func availability(for locale: Locale) -> AssetModelAvailability {
        availability
    }
}
