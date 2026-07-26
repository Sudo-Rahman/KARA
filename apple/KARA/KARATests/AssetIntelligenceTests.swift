import Foundation
import Testing
@testable import KARA

@Suite("Remote asset intelligence")
struct AssetIntelligenceTests {
    @Test("The remote suggestion is returned directly")
    func returnsRemoteSuggestion() async throws {
        let remote = StubRemoteAnalyzer(
            outcome: .success(AssetAnalysisSuggestion(name: "Lingotin"))
        )
        let service = makeService(remote: remote)

        let suggestion = try await service.analyzeObjectPhoto(Data([0x01]))

        #expect(suggestion.name?.value == "Lingotin")
        #expect(await remote.callCount() == 1)
    }

    @Test(
        "Connectivity failures are reported without local fallback",
        arguments: [
            URLError.Code.notConnectedToInternet,
            .networkConnectionLost,
            .cannotFindHost,
            .cannotConnectToHost,
            .dnsLookupFailed,
        ]
    )
    func reportsNetworkFailure(code: URLError.Code) async {
        let service = makeService(
            remote: StubRemoteAnalyzer(outcome: .urlFailure(code))
        )

        await #expect(throws: AssetAnalysisError.unavailable) {
            try await service.analyzeObjectPhoto(Data([0x01]))
        }
    }

    @Test("A network timeout uses the domain timeout error")
    func mapsNetworkTimeout() async {
        let service = makeService(
            remote: StubRemoteAnalyzer(outcome: .urlFailure(.timedOut))
        )

        await #expect(throws: AssetAnalysisError.timeout) {
            try await service.analyzeObjectPhoto(Data([0x01]))
        }
    }

    @Test("A cancelled network task remains a cancellation")
    func preservesCancellation() async {
        let service = makeService(
            remote: StubRemoteAnalyzer(outcome: .urlFailure(.cancelled))
        )

        await #expect(throws: CancellationError.self) {
            try await service.analyzeObjectPhoto(Data([0x01]))
        }
    }

    @Test(
        "Server and policy errors are preserved",
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
    func preservesDomainFailure(error: AssetAnalysisError) async {
        let service = makeService(
            remote: StubRemoteAnalyzer(outcome: .failure(error))
        )

        await #expect(throws: error) {
            try await service.analyzeObjectPhoto(Data([0x01]))
        }
    }

    private func makeService(
        remote: StubRemoteAnalyzer
    ) -> RemoteAssetAnalysisService {
        RemoteAssetAnalysisService(
            remoteAnalyzer: remote,
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

    private let outcome: Outcome
    private var calls = 0

    init(outcome: Outcome) {
        self.outcome = outcome
    }

    func analyze(
        kind: AssetExtractionKind,
        data: Data,
        locale: Locale
    ) async throws -> AssetAnalysisSuggestion {
        calls += 1
        switch outcome {
        case let .success(suggestion):
            return suggestion
        case let .failure(error):
            throw error
        case let .urlFailure(code):
            throw URLError(code)
        }
    }

    func callCount() -> Int {
        calls
    }
}
