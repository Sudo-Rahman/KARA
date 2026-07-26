import Foundation

nonisolated protocol AssetAnalyzing: Sendable {
    func analyzeObjectPhoto(_ data: Data) async throws -> AssetAnalysisSuggestion

    func analyzeInvoice(_ document: PreparedMediaDocument) async throws -> AssetAnalysisSuggestion
}

nonisolated enum AssetAnalysisError: Error, Equatable, Sendable {
    case invalidInput
    case payloadTooLarge
    case refused
    case rateLimited
    case dailyLimitReached
    case quarantined
    case unavailable
    case timeout
    case invalidResponse
    case technicalFailure
}
