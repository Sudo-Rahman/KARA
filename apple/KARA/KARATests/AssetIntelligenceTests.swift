import Foundation
import Testing
@testable import KARA

@Suite("Remote-first asset intelligence")
struct AssetIntelligenceTests {
    @Test("An online response is used without invoking the local model")
    func onlineResponseWins() async throws {
        let remote = StubRemoteAnalyzer(
            outcome: .success(AssetAnalysisSuggestion(name: "Lingotin"))
        )
        let local = RecordingLocalAnalyzer(
            outcome: .success(AssetAnalysisSuggestion(name: "Hors ligne"))
        )
        let service = makeService(remote: remote, local: local)

        let result = try await service.analyzeObjectPhoto(Data([0x01]))

        #expect(result.source == .online)
        #expect(result.suggestion.name == "Lingotin")
        #expect(await local.callCount() == 0)
    }

    @Test(
        "Expected connectivity failures fall back to the local model",
        arguments: [
            URLError.Code.notConnectedToInternet,
            .networkConnectionLost,
            .cannotFindHost,
            .cannotConnectToHost,
            .dnsLookupFailed,
            .timedOut,
        ]
    )
    func networkFailuresUseLocalModel(code: URLError.Code) async throws {
        let remote = StubRemoteAnalyzer(outcome: .urlFailure(code))
        let local = RecordingLocalAnalyzer(
            outcome: .success(AssetAnalysisSuggestion(name: "Napoléon"))
        )
        let service = makeService(remote: remote, local: local)

        let result = try await service.analyzeObjectPhoto(Data([0x01]))

        #expect(result.source == .offline)
        #expect(result.suggestion.name == "Napoléon")
        #expect(await local.callCount() == 1)
    }

    @Test("A cancelled network task remains a cancellation and never falls back")
    func cancelledNetworkTaskDoesNotUseLocalModel() async {
        let remote = StubRemoteAnalyzer(outcome: .urlFailure(.cancelled))
        let local = RecordingLocalAnalyzer(
            outcome: .success(AssetAnalysisSuggestion(name: "Ne doit pas servir"))
        )
        let service = makeService(remote: remote, local: local)

        await #expect(throws: CancellationError.self) {
            try await service.analyzeObjectPhoto(Data([0x01]))
        }
        #expect(await local.callCount() == 0)
    }

    @Test(
        "Server and policy errors never fall back locally",
        arguments: [
            AssetAnalysisError.rateLimited,
            .dailyLimitReached,
            .quarantined,
            .refused,
            .payloadTooLarge,
            .invalidResponse,
            .technicalFailure,
        ]
    )
    func httpAndPolicyFailuresDoNotUseLocalModel(error: AssetAnalysisError) async {
        let remote = StubRemoteAnalyzer(outcome: .failure(error))
        let local = RecordingLocalAnalyzer(
            outcome: .success(AssetAnalysisSuggestion(name: "Ne doit pas servir"))
        )
        let service = makeService(remote: remote, local: local)

        await #expect(throws: error) {
            try await service.analyzeObjectPhoto(Data([0x01]))
        }
        #expect(await local.callCount() == 0)
    }

    @Test("A local fallback remains unavailable when the device model is unavailable")
    func unavailableLocalModelStopsFallback() async {
        let service = RemoteFirstAssetAnalysisService(
            remoteAnalyzer: StubRemoteAnalyzer(outcome: .urlFailure(.notConnectedToInternet)),
            localAnalyzer: RecordingLocalAnalyzer(
                outcome: .success(AssetAnalysisSuggestion(name: "Local"))
            ),
            availabilityChecker: StaticModelAvailability(availability: .unavailable),
            objectPhotoProcessor: StubObjectPhotoProcessor(),
            locale: Locale(identifier: "fr_FR")
        )

        await #expect(throws: AssetAnalysisError.unavailable) {
            try await service.analyzeObjectPhoto(Data([0x01]))
        }
    }

    @Test("Generated local fields are validated and serial formatting is preserved")
    func generatedFieldsAreValidated() throws {
        let amount = try #require(Decimal(string: "2390.005"))
        let generated = GeneratedAssetAnalysis(
            name: .init(value: "  Lingotin   10 g ", confidencePercent: 98, evidenceKind: "visible_text"),
            category: .init(value: "bar", confidencePercent: 94, evidenceKind: "visual_identification"),
            presetID: .init(value: "gold-bar-10g", confidencePercent: 91, evidenceKind: "visual_identification"),
            quantity: .init(value: 0, confidencePercent: 80, evidenceKind: "context_inference"),
            purchaseDateISO8601: .init(value: "2024-05-14", confidencePercent: 99, evidenceKind: "visible_text"),
            metal: .init(value: "gold", confidencePercent: 97, evidenceKind: "visible_text"),
            weightGrams: .init(value: .nan, confidencePercent: 95, evidenceKind: "visible_text"),
            metalKarat: .init(value: 25, confidencePercent: 70, evidenceKind: "context_inference"),
            finenessPermille: .init(value: 999.9, confidencePercent: 99, evidenceKind: "visible_text"),
            gemstoneCaratWeight: .init(value: -1, confidencePercent: 40, evidenceKind: "context_inference"),
            gemstoneClarity: .init(value: " ", confidencePercent: 20, evidenceKind: "visible_text"),
            pricePaid: .init(
                amount: amount,
                currencyCode: " eur ",
                confidencePercent: 98,
                evidenceKind: "visible_text"
            ),
            sellerName: .init(value: "  Maison   Lemoine ", confidencePercent: 96, evidenceKind: "visible_text"),
            storageLocationName: .init(value: " ", confidencePercent: 10, evidenceKind: "context_inference"),
            invoiceNumber: .init(value: " ML2024-05872 ", confidencePercent: 99, evidenceKind: "visible_text"),
            serialNumber: .init(value: " 00-AbC-42 ", confidencePercent: 99, evidenceKind: "visible_text"),
            acquisitionMethod: .init(value: "purchase", confidencePercent: 85, evidenceKind: "context_inference"),
            tags: [.init(value: "Or d’investissement", confidencePercent: 75, evidenceKind: "context_inference")]
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
        #expect(suggestion.pricePaidMinorUnits == 239_001)
        #expect(suggestion.currencyCode == "EUR")
        #expect(suggestion.sellerName == "Maison Lemoine")
        #expect(suggestion.invoiceNumber == "ML2024-05872")
        #expect(suggestion.serialNumber == "00-AbC-42")
        #expect(suggestion.acquisitionMethod == .purchase)
        #expect(suggestion.tags == ["Or d’investissement"])
        #expect(suggestion.assessment(for: .finenessPermille)?.confidencePercent == 99)
    }

    private func makeService(
        remote: StubRemoteAnalyzer,
        local: RecordingLocalAnalyzer
    ) -> RemoteFirstAssetAnalysisService {
        RemoteFirstAssetAnalysisService(
            remoteAnalyzer: remote,
            localAnalyzer: local,
            availabilityChecker: StaticModelAvailability(availability: .ready),
            objectPhotoProcessor: StubObjectPhotoProcessor(),
            locale: Locale(identifier: "fr_FR")
        )
    }
}

private actor StubRemoteAnalyzer: RemoteAssetAnalyzing {
    enum Outcome: Sendable {
        case success(AssetAnalysisSuggestion)
        case failure(AssetAnalysisError)
        case urlFailure(URLError.Code)
    }

    let outcome: Outcome

    init(outcome: Outcome) { self.outcome = outcome }

    func analyze(
        kind: AssetExtractionKind,
        data: Data,
        locale: Locale
    ) async throws -> AssetAnalysisSuggestion {
        switch outcome {
        case let .success(suggestion): return suggestion
        case let .failure(error): throw error
        case let .urlFailure(code): throw URLError(code)
        }
    }
}

private actor RecordingLocalAnalyzer: AssetModelAnalyzing {
    enum Outcome: Sendable {
        case success(AssetAnalysisSuggestion)
        case failure(AssetAnalysisError)
    }

    private let outcome: Outcome
    private var calls = 0

    init(outcome: Outcome) { self.outcome = outcome }

    func analyze(_ input: AssetModelAnalysisInput) async throws -> AssetAnalysisSuggestion {
        calls += 1
        switch outcome {
        case let .success(suggestion): return suggestion
        case let .failure(error): throw error
        }
    }

    func callCount() -> Int { calls }
}

private struct StaticModelAvailability: AssetModelAvailabilityChecking {
    let availability: AssetModelReadiness

    func availability(for locale: Locale) -> AssetModelReadiness { availability }
}

private struct StubObjectPhotoProcessor: ObjectPhotoProcessing {
    func prepare(jpegData: Data) async throws -> PreparedObjectPhotoDocument {
        PreparedObjectPhotoDocument(
            jpegData: jpegData,
            ocrText: "OR FIN 999.9 00-AbC-42",
            classifications: ["gold bar"]
        )
    }
}
