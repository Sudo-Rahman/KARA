import Foundation
import Observation

enum AssetCreationStep: Int, CaseIterable, Identifiable, Sendable {
    case objectPhoto
    case invoice
    case classification
    case characteristics
    case purchase
    case summary

    var id: Self { self }
}

@MainActor
@Observable
final class AssetCreationRouter {
    var path: [AssetCreationStep]

    init(path: [AssetCreationStep] = []) {
        self.path = path
    }

    var currentStep: AssetCreationStep {
        path.last ?? .objectPhoto
    }

    func advance(to step: AssetCreationStep) {
        guard step.rawValue == currentStep.rawValue + 1 else { return }
        path.append(step)
    }

    func goBack() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func editCharacteristics() {
        guard let index = path.firstIndex(of: .characteristics) else { return }
        path.removeSubrange(path.index(after: index)..<path.endIndex)
    }
}

enum AssetAnalysisPhase: Equatable, Sendable {
    case idle
    case analyzing
    case completed(AssetAnalysisSource)
    case failed(AssetAnalysisError)

    var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }
}

struct AssetCreationIssue: Identifiable, Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case objectAnalysis
        case invoiceAnalysis
        case media
        case save
    }

    let id = UUID()
    let kind: Kind
    let localizationKey: String
}

@MainActor
@Observable
final class AssetCreationState {
    private(set) var step: AssetCreationStep = .objectPhoto
    var draft: AssetDraft
    private(set) var objectPhotoData: Data?
    private(set) var invoiceDocument: PreparedMediaDocument?
    private(set) var objectAnalysisPhase: AssetAnalysisPhase = .idle
    private(set) var invoiceAnalysisPhase: AssetAnalysisPhase = .idle
    private(set) var issue: AssetCreationIssue?
    private(set) var isSaving = false
    private(set) var savedAsset: Asset?
    private(set) var validationAttempted = false

    @ObservationIgnored
    private let analyzer: any AssetAnalyzing

    @ObservationIgnored
    private let analysisPreferences: AIFormAutofillPreferences

    @ObservationIgnored
    private let saver: any AssetSaving

    @ObservationIgnored
    private let pristineDraft: AssetDraft

    @ObservationIgnored
    private var objectAnalysisTask: Task<Void, Never>?

    @ObservationIgnored
    private var invoiceAnalysisTask: Task<Void, Never>?

    @ObservationIgnored
    private var analysisSuggestedFields: Set<AssetDraft.Field> = []

    @ObservationIgnored
    private var objectSuggestion: AssetAnalysisSuggestion?

    @ObservationIgnored
    private var invoiceSuggestion: AssetAnalysisSuggestion?

    init(
        draft: AssetDraft = AssetDraft(),
        analyzer: any AssetAnalyzing,
        analysisPreferences: AIFormAutofillPreferences,
        saver: any AssetSaving
    ) {
        var initialDraft = draft
        if initialDraft.acquisitionMethod == nil {
            initialDraft.acquisitionMethod = .purchase
        }
        self.draft = initialDraft
        pristineDraft = initialDraft
        self.analyzer = analyzer
        self.analysisPreferences = analysisPreferences
        self.saver = saver
    }

    var canAdvanceFromDetails: Bool {
        draft.isValid
    }

    @discardableResult
    func validateDraft() -> Bool {
        validationAttempted = true
        return draft.isValid
    }

    var hasUserContent: Bool {
        objectPhotoData != nil
            || invoiceDocument != nil
            || draft != pristineDraft
    }

    var attachments: [AssetAttachmentPayload] {
        var payloads: [AssetAttachmentPayload] = []

        if let objectPhotoData {
            payloads.append(
                AssetAttachmentPayload(
                    kind: .objectPhoto,
                    filename: "objet.jpg",
                    mimeType: "image/jpeg",
                    pageCount: 1,
                    data: objectPhotoData
                )
            )
        }

        if let invoiceDocument {
            payloads.append(
                AssetAttachmentPayload(
                    kind: .invoice,
                    filename: invoiceDocument.filename,
                    mimeType: invoiceDocument.mimeType,
                    pageCount: invoiceDocument.pageCount,
                    data: invoiceDocument.data
                )
            )
        }

        return payloads
    }

    func skipCurrentStep() {
        switch step {
        case .objectPhoto:
            step = .invoice
        case .invoice:
            step = .classification
        case .classification, .characteristics, .purchase, .summary:
            break
        }
    }

    func advanceFromObjectPhoto() {
        guard step == .objectPhoto else { return }
        step = .invoice
    }

    func advanceFromInvoice() {
        guard step == .invoice else { return }
        step = .classification
    }

    @discardableResult
    func advanceFromDetails() -> Bool {
        guard step == .characteristics, validateDraft() else {
            return false
        }

        step = .purchase
        return true
    }

    func goBack() {
        switch step {
        case .objectPhoto:
            break
        case .invoice:
            step = .objectPhoto
        case .classification:
            step = .invoice
        case .characteristics:
            step = .classification
        case .purchase:
            step = .characteristics
        case .summary:
            step = .purchase
        }
    }

    func update<Value>(
        _ keyPath: WritableKeyPath<AssetDraft, Value>,
        to value: Value,
        field: AssetDraft.Field
    ) {
        draft[keyPath: keyPath] = value
        draft.markAsManuallyEdited(field)
    }

    func applyPreset(_ preset: AssetPreset, localizedName: String? = nil) {
        draft.apply(preset: preset)
        if let localizedName {
            draft.name = localizedName
        }
        for field in [
            AssetDraft.Field.presetID,
            .category,
            .name,
            .metal,
            .weightGrams,
            .metalKarat,
            .finenessPermille,
        ] {
            draft.markAsManuallyEdited(field)
        }
    }

    func clearPresetSelection() {
        guard draft.presetID != nil else { return }

        update(\.presetID, to: nil, field: .presetID)
        update(\.name, to: "", field: .name)
        update(\.weightGrams, to: nil, field: .weightGrams)
        update(\.metalKarat, to: nil, field: .metalKarat)
        update(\.finenessPermille, to: nil, field: .finenessPermille)
    }

    func updateCurrencyCode(_ value: String) {
        let oldAmount = draft.pricePaidMinorUnits.flatMap {
            MoneyConverter.decimalAmount(
                from: $0,
                currencyCode: draft.currencyCode
            )
        }
        let newCode = String(value.uppercased().prefix(3))

        draft.currencyCode = newCode
        draft.markAsManuallyEdited(.currencyCode)

        guard let oldAmount else { return }
        draft.pricePaidMinorUnits = MoneyConverter.minorUnits(
            from: oldAmount,
            currencyCode: newCode
        )
        draft.markAsManuallyEdited(.pricePaidMinorUnits)
    }

    func setObjectPhoto(_ data: Data) {
        objectAnalysisTask?.cancel()
        objectSuggestion = nil
        reapplyAnalysisSuggestions()
        objectPhotoData = data
        issue = nil

        guard analysisPreferences.isEnabled else {
            objectAnalysisPhase = .idle
            return
        }
        objectAnalysisPhase = .analyzing

        objectAnalysisTask = Task { [weak self, analyzer] in
            do {
                let result = try await analyzer.analyzeObjectPhoto(data)
                try Task.checkCancellation()
                guard let self else { return }
                objectSuggestion = result.suggestion
                reapplyAnalysisSuggestions()
                objectAnalysisPhase = .completed(result.source)
            } catch is CancellationError {
                return
            } catch let error as AssetAnalysisError {
                guard let self, !Task.isCancelled else { return }
                objectAnalysisPhase = .failed(error)
                issue = AssetCreationIssue(
                    kind: .objectAnalysis,
                    localizationKey: Self.localizationKey(for: error)
                )
            } catch {
                guard let self, !Task.isCancelled else { return }
                objectAnalysisPhase = .failed(.technicalFailure)
                issue = AssetCreationIssue(
                    kind: .objectAnalysis,
                    localizationKey: Self.localizationKey(for: .technicalFailure)
                )
            }
        }
    }

    func removeObjectPhoto() {
        objectAnalysisTask?.cancel()
        objectAnalysisTask = nil
        objectSuggestion = nil
        reapplyAnalysisSuggestions()
        objectPhotoData = nil
        objectAnalysisPhase = .idle
    }

    func setInvoiceDocument(_ document: PreparedMediaDocument) {
        invoiceAnalysisTask?.cancel()
        invoiceSuggestion = nil
        reapplyAnalysisSuggestions()
        invoiceDocument = document
        issue = nil

        guard analysisPreferences.isEnabled else {
            invoiceAnalysisPhase = .idle
            return
        }
        invoiceAnalysisPhase = .analyzing

        invoiceAnalysisTask = Task { [weak self, analyzer] in
            do {
                let result = try await analyzer.analyzeInvoice(
                    document.data,
                    filename: document.filename,
                    mimeType: document.mimeType
                )
                try Task.checkCancellation()
                guard let self else { return }
                invoiceSuggestion = result.suggestion
                reapplyAnalysisSuggestions()
                invoiceAnalysisPhase = .completed(result.source)
            } catch is CancellationError {
                return
            } catch let error as AssetAnalysisError {
                guard let self, !Task.isCancelled else { return }
                invoiceAnalysisPhase = .failed(error)
                issue = AssetCreationIssue(
                    kind: .invoiceAnalysis,
                    localizationKey: Self.localizationKey(for: error)
                )
            } catch {
                guard let self, !Task.isCancelled else { return }
                invoiceAnalysisPhase = .failed(.technicalFailure)
                issue = AssetCreationIssue(
                    kind: .invoiceAnalysis,
                    localizationKey: Self.localizationKey(for: .technicalFailure)
                )
            }
        }
    }

    func removeInvoiceDocument() {
        invoiceAnalysisTask?.cancel()
        invoiceAnalysisTask = nil
        invoiceSuggestion = nil
        reapplyAnalysisSuggestions()
        invoiceDocument = nil
        invoiceAnalysisPhase = .idle
    }

    private func reapplyAnalysisSuggestions() {
        draft.clearSuggestedFields(analysisSuggestedFields)
        analysisSuggestedFields.removeAll()

        let resolved = AssetAnalysisSuggestionResolver.resolve(
            objectPhoto: objectSuggestion,
            invoice: invoiceSuggestion,
            preserving: draft
        )
        var excludedFields: Set<AssetDraft.Field> = []
        let moneyFields: Set<AssetDraft.Field> = [.pricePaidMinorUnits, .currencyCode]
        if !draft.manuallyEditedFields.isDisjoint(with: moneyFields) {
            excludedFields.formUnion(moneyFields)
        }
        analysisSuggestedFields = draft.merge(
            suggestion: resolved,
            excluding: excludedFields
        )
    }

    func reportMediaFailure() {
        issue = AssetCreationIssue(
            kind: .media,
            localizationKey: "asset-flow.error.media"
        )
    }

    func dismissIssue() {
        issue = nil
    }

    @discardableResult
    func save() -> Asset? {
        guard draft.isValid, !isSaving else { return nil }

        isSaving = true
        issue = nil
        defer { isSaving = false }

        do {
            let asset = try saver.save(draft: draft, attachments: attachments)
            savedAsset = asset
            return asset
        } catch {
            issue = AssetCreationIssue(
                kind: .save,
                localizationKey: "asset-flow.error.save"
            )
            return nil
        }
    }

    func cancelAllWork() {
        objectAnalysisTask?.cancel()
        invoiceAnalysisTask?.cancel()
        objectAnalysisTask = nil
        invoiceAnalysisTask = nil

        if objectAnalysisPhase == .analyzing {
            objectAnalysisPhase = .idle
        }
        if invoiceAnalysisPhase == .analyzing {
            invoiceAnalysisPhase = .idle
        }
    }

    func analysisPreferenceDidChange() {
        guard !analysisPreferences.isEnabled else { return }
        cancelAllWork()
        objectSuggestion = nil
        invoiceSuggestion = nil
        reapplyAnalysisSuggestions()
        objectAnalysisPhase = .idle
        invoiceAnalysisPhase = .idle
        if issue?.kind == .objectAnalysis || issue?.kind == .invoiceAnalysis {
            issue = nil
        }
    }

    private static func localizationKey(for error: AssetAnalysisError) -> String {
        switch error {
        case .rateLimited:
            "asset-flow.error.analysis-rate-limited"
        case .dailyLimitReached:
            "asset-flow.error.analysis-daily-limit"
        case .quarantined:
            "asset-flow.error.analysis-quarantined"
        case .payloadTooLarge:
            "asset-flow.error.analysis-payload-too-large"
        case .refused:
            "asset-flow.error.analysis-refused"
        case .timeout, .unavailable:
            "asset-flow.error.analysis-unavailable"
        case .invalidInput:
            "asset-flow.error.analysis-invalid-input"
        case .cancelled:
            "asset-flow.error.analysis-unavailable"
        case .invalidResponse, .technicalFailure:
            "asset-flow.error.analysis-technical"
        }
    }
}
