import Foundation
import FoundationModels

nonisolated enum AssetModelReadiness: Equatable, Sendable {
    case ready
    case unavailable
}

nonisolated protocol AssetModelAvailabilityChecking: Sendable {
    func availability(for locale: Locale) -> AssetModelReadiness
}

nonisolated struct AssetModelAnalysisInput: Equatable, Sendable {
    nonisolated enum Content: Equatable, Sendable {
        case objectPhoto(PreparedObjectPhotoDocument)
        case invoice(PreparedInvoiceDocument)
    }

    let content: Content
    let locale: Locale
}

nonisolated protocol AssetModelAnalyzing: Sendable {
    func analyze(_ input: AssetModelAnalysisInput) async throws -> AssetAnalysisSuggestion
}

nonisolated struct RemoteFirstAssetAnalysisService: AssetAnalyzing {
    private let remoteAnalyzer: any RemoteAssetAnalyzing
    private let localAnalyzer: any AssetModelAnalyzing
    private let availabilityChecker: any AssetModelAvailabilityChecking
    private let invoiceProcessor: InvoiceDocumentProcessor
    private let objectPhotoProcessor: any ObjectPhotoProcessing
    private let locale: Locale

    init(
        remoteAnalyzer: any RemoteAssetAnalyzing = RemoteAssetAnalysisClient(),
        localAnalyzer: any AssetModelAnalyzing = FoundationModelAssetAnalyzer(),
        availabilityChecker: any AssetModelAvailabilityChecking = SystemAssetModelAvailabilityChecker(),
        invoiceProcessor: InvoiceDocumentProcessor = InvoiceDocumentProcessor(),
        objectPhotoProcessor: any ObjectPhotoProcessing = ObjectPhotoProcessor(),
        locale: Locale = .autoupdatingCurrent
    ) {
        self.remoteAnalyzer = remoteAnalyzer
        self.localAnalyzer = localAnalyzer
        self.availabilityChecker = availabilityChecker
        self.invoiceProcessor = invoiceProcessor
        self.objectPhotoProcessor = objectPhotoProcessor
        self.locale = locale
    }

    func analyzeObjectPhoto(_ data: Data) async throws -> AssetAnalysisResult {
        do {
            let suggestion = try await remoteAnalyzer.analyze(
                kind: .objectPhoto,
                data: data,
                locale: locale
            )
            return AssetAnalysisResult(suggestion: suggestion, source: .online)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as AssetAnalysisError where error == .cancelled {
            throw CancellationError()
        } catch {
            guard Self.allowsOfflineFallback(for: error) else { throw error }
        }

        let prepared: PreparedObjectPhotoDocument
        do {
            prepared = try await objectPhotoProcessor.prepare(jpegData: data)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw AssetAnalysisError.invalidInput
        }
        return try await analyzeLocally(.objectPhoto(prepared))
    }

    func analyzeInvoice(
        _ data: Data,
        filename: String,
        mimeType: String
    ) async throws -> AssetAnalysisResult {
        let mediaDocument: PreparedMediaDocument
        do {
            mediaDocument = try MediaDocumentFactory.invoiceDocument(
                fromImportedData: data,
                filename: filename,
                mimeType: mimeType
            )
        } catch {
            throw AssetAnalysisError.invalidInput
        }

        let prepared: PreparedInvoiceDocument
        do {
            prepared = try await invoiceProcessor.prepare(
                pdfData: mediaDocument.data,
                includingOCR: false
            )
        } catch is CancellationError {
            throw CancellationError()
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

        do {
            let suggestion = try await remoteAnalyzer.analyze(
                kind: .invoice,
                data: prepared.analysisPDFData,
                locale: locale
            )
            return AssetAnalysisResult(suggestion: suggestion, source: .online)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as AssetAnalysisError where error == .cancelled {
            throw CancellationError()
        } catch {
            guard Self.allowsOfflineFallback(for: error) else { throw error }
        }

        let localDocument: PreparedInvoiceDocument
        do {
            localDocument = try await invoiceProcessor.prepare(
                pdfData: mediaDocument.data,
                includingOCR: true
            )
        } catch is CancellationError {
            throw CancellationError()
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
        return try await analyzeLocally(.invoice(localDocument))
    }

    private func analyzeLocally(
        _ content: AssetModelAnalysisInput.Content
    ) async throws -> AssetAnalysisResult {
        try Task.checkCancellation()
        guard availabilityChecker.availability(for: locale) == .ready else {
            throw AssetAnalysisError.unavailable
        }
        do {
            let suggestion = try await localAnalyzer.analyze(
                AssetModelAnalysisInput(content: content, locale: locale)
            )
            return AssetAnalysisResult(suggestion: suggestion, source: .offline)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as AssetAnalysisError {
            if error == .cancelled { throw CancellationError() }
            throw error
        } catch {
            throw AssetAnalysisError.technicalFailure
        }
    }

    nonisolated static func allowsOfflineFallback(for error: Error) -> Bool {
        guard let urlError = error as? URLError else { return false }
        return switch urlError.code {
        case .notConnectedToInternet,
             .networkConnectionLost,
             .cannotFindHost,
             .cannotConnectToHost,
             .dnsLookupFailed,
             .timedOut:
            true
        default:
            false
        }
    }
}

nonisolated struct SystemAssetModelAvailabilityChecker: AssetModelAvailabilityChecking {
    func availability(for locale: Locale) -> AssetModelReadiness {
        let model = SystemLanguageModel.default
        guard model.availability == .available,
              model.supportsLocale(locale),
              model.capabilities.contains(.guidedGeneration)
        else { return .unavailable }
        return .ready
    }
}
