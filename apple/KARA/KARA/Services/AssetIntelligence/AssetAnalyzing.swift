import Foundation

nonisolated protocol AssetAnalyzing: Sendable {
    func analyzeObjectPhoto(_ data: Data) async throws -> AssetAnalysisSuggestion

    func analyzeInvoice(
        _ data: Data,
        filename: String,
        mimeType: String
    ) async throws -> AssetAnalysisSuggestion
}

nonisolated enum AssetAnalysisError: Error, Equatable, Sendable {
    case invalidInput
    case cancelled
    case refused
    case unavailable
    case technicalFailure
}
