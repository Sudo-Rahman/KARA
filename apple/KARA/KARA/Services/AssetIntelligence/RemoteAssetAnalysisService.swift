import Foundation

nonisolated struct RemoteAssetAnalysisService: AssetAnalyzing {
    private let remoteAnalyzer: any RemoteAssetAnalyzing
    private let invoiceProcessor: InvoiceDocumentProcessor
    private let locale: Locale

    init(
        remoteAnalyzer: any RemoteAssetAnalyzing = RemoteAssetAnalysisClient(),
        invoiceProcessor: InvoiceDocumentProcessor = InvoiceDocumentProcessor(),
        locale: Locale = .autoupdatingCurrent
    ) {
        self.remoteAnalyzer = remoteAnalyzer
        self.invoiceProcessor = invoiceProcessor
        self.locale = locale
    }

    func analyzeObjectPhoto(_ data: Data) async throws -> AssetAnalysisSuggestion {
        try await analyze(kind: .objectPhoto, data: data)
    }

    func analyzeInvoice(_ document: PreparedMediaDocument) async throws -> AssetAnalysisSuggestion {
        let analysisData: Data
        do {
            analysisData = try invoiceProcessor.prepare(pdfData: document.data)
        } catch let error as MediaDocumentError {
            switch error {
            case .invalidImage, .invalidPDF, .emptyDocument:
                throw AssetAnalysisError.invalidInput
            case .encodingFailed:
                throw AssetAnalysisError.technicalFailure
            }
        } catch {
            throw AssetAnalysisError.technicalFailure
        }

        return try await analyze(kind: .invoice, data: analysisData)
    }

    private func analyze(
        kind: AssetExtractionKind,
        data: Data
    ) async throws -> AssetAnalysisSuggestion {
        do {
            return try await remoteAnalyzer.analyze(
                kind: kind,
                data: data,
                locale: locale
            )
        } catch let error as URLError {
            switch error.code {
            case .cancelled:
                throw CancellationError()
            case .timedOut:
                throw AssetAnalysisError.timeout
            case .notConnectedToInternet,
                 .networkConnectionLost,
                 .cannotFindHost,
                 .cannotConnectToHost,
                 .dnsLookupFailed:
                throw AssetAnalysisError.unavailable
            default:
                throw AssetAnalysisError.technicalFailure
            }
        }
    }
}
