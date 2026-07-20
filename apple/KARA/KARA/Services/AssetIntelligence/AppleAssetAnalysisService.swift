import Foundation
import FoundationModels

nonisolated enum AssetIntelligenceModelRoute: Hashable, Sendable {
    case onDevice
    case privateCloudCompute
}

nonisolated enum AssetModelReadiness: Equatable, Sendable {
    case ready
    case unavailable
}

nonisolated struct AssetModelAvailability: Equatable, Sendable {
    let onDevice: AssetModelReadiness
    let privateCloudCompute: AssetModelReadiness
}

nonisolated protocol AssetModelAvailabilityChecking: Sendable {
    func availability(for locale: Locale) -> AssetModelAvailability
}

nonisolated struct AssetModelAnalysisInput: Equatable, Sendable {
    nonisolated enum Content: Equatable, Sendable {
        case objectPhoto(Data)
        case invoice(PreparedInvoiceDocument)
    }

    let content: Content
    let locale: Locale
}

nonisolated protocol AssetModelAnalyzing: Sendable {
    func analyze(
        _ input: AssetModelAnalysisInput,
        using route: AssetIntelligenceModelRoute
    ) async throws -> AssetAnalysisSuggestion
}

nonisolated struct AppleAssetAnalysisService: AssetAnalyzing {
    private let availabilityChecker: any AssetModelAvailabilityChecking
    private let modelAnalyzer: any AssetModelAnalyzing
    private let invoiceProcessor: InvoiceDocumentProcessor
    private let locale: Locale

    init(
        availabilityChecker: any AssetModelAvailabilityChecking = AppleAssetModelAvailabilityChecker(),
        modelAnalyzer: any AssetModelAnalyzing = FoundationModelAssetAnalyzer(),
        invoiceProcessor: InvoiceDocumentProcessor = InvoiceDocumentProcessor(),
        locale: Locale = .autoupdatingCurrent
    ) {
        self.availabilityChecker = availabilityChecker
        self.modelAnalyzer = modelAnalyzer
        self.invoiceProcessor = invoiceProcessor
        self.locale = locale
    }

    func analyzeObjectPhoto(_ data: Data) async throws -> AssetAnalysisSuggestion {
        let normalizedData: Data
        do {
            normalizedData = try MediaDocumentFactory.normalizedObjectJPEG(from: data)
        } catch {
            throw AssetAnalysisError.invalidInput
        }

        return try await analyze(
            AssetModelAnalysisInput(
                content: .objectPhoto(normalizedData),
                locale: locale
            )
        )
    }

    func analyzeInvoice(
        _ data: Data,
        filename: String,
        mimeType: String
    ) async throws -> AssetAnalysisSuggestion {
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
            prepared = try await invoiceProcessor.prepare(pdfData: mediaDocument.data)
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

        return try await analyze(
            AssetModelAnalysisInput(content: .invoice(prepared), locale: locale)
        )
    }

    private func analyze(
        _ input: AssetModelAnalysisInput
    ) async throws -> AssetAnalysisSuggestion {
        try Task.checkCancellation()
        let availability = availabilityChecker.availability(for: input.locale)

        if availability.onDevice == .ready {
            do {
                return try await modelAnalyzer.analyze(input, using: .onDevice)
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as AssetAnalysisError {
                switch error {
                case .cancelled:
                    throw CancellationError()
                case .refused, .invalidInput:
                    throw error
                case .unavailable, .technicalFailure:
                    break
                }
            } catch {
                // Unexpected on-device failures are technical and may use PCC.
            }
        }

        guard availability.privateCloudCompute == .ready else {
            throw AssetAnalysisError.unavailable
        }

        do {
            return try await modelAnalyzer.analyze(input, using: .privateCloudCompute)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as AssetAnalysisError {
            if error == .cancelled {
                throw CancellationError()
            }
            throw error
        } catch {
            throw AssetAnalysisError.technicalFailure
        }
    }
}

nonisolated struct AppleAssetModelAvailabilityChecker: AssetModelAvailabilityChecking {
    func availability(for locale: Locale) -> AssetModelAvailability {
        let onDevice = SystemLanguageModel.default
        let cloud = PrivateCloudComputeLanguageModel()

        return AssetModelAvailability(
            onDevice: readiness(
                isAvailable: onDevice.availability == .available,
                supportsLocale: onDevice.supportsLocale(locale),
                capabilities: onDevice.capabilities
            ),
            privateCloudCompute: readiness(
                isAvailable: cloud.availability == .available,
                supportsLocale: cloud.supportsLocale(locale),
                capabilities: cloud.capabilities
            )
        )
    }

    private func readiness(
        isAvailable: Bool,
        supportsLocale: Bool,
        capabilities: LanguageModelCapabilities
    ) -> AssetModelReadiness {
        guard isAvailable,
              supportsLocale,
              capabilities.contains(.vision),
              capabilities.contains(.guidedGeneration)
        else {
            return .unavailable
        }
        return .ready
    }
}
