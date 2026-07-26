import Foundation

nonisolated protocol AssetAnalyzing: Sendable {
    func analyzeObjectPhoto(_ data: Data) async throws -> AssetAnalysisResult

    func analyzeInvoice(
        _ data: Data,
        filename: String,
        mimeType: String
    ) async throws -> AssetAnalysisResult
}

nonisolated enum AssetAnalysisSource: Equatable, Sendable {
    case online
    case offline
}

nonisolated struct AssetAnalysisResult: Equatable, Sendable {
    let suggestion: AssetAnalysisSuggestion
    let source: AssetAnalysisSource
}

nonisolated enum AssetAnalysisError: Error, Equatable, Sendable {
    case invalidInput
    case payloadTooLarge
    case cancelled
    case refused
    case rateLimited
    case dailyLimitReached
    case quarantined
    case unavailable
    case timeout
    case invalidResponse
    case technicalFailure
}
