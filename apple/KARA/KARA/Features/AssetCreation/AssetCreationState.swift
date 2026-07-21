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
    case completed
    case unavailable
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
    private let saver: any AssetSaving

    @ObservationIgnored
    private let pristineDraft: AssetDraft

    @ObservationIgnored
    private var objectAnalysisTask: Task<Void, Never>?

    @ObservationIgnored
    private var invoiceAnalysisTask: Task<Void, Never>?

    @ObservationIgnored
    private var objectSuggestedFields: Set<AssetDraft.Field> = []

    @ObservationIgnored
    private var invoiceSuggestedFields: Set<AssetDraft.Field> = []

    @ObservationIgnored
    private var objectSuggestion: AssetAnalysisSuggestion?

    @ObservationIgnored
    private var invoiceSuggestion: AssetAnalysisSuggestion?

    init(
        draft: AssetDraft = AssetDraft(),
        analyzer: any AssetAnalyzing,
        saver: any AssetSaving
    ) {
        var initialDraft = draft
        if initialDraft.acquisitionMethod == nil {
            initialDraft.acquisitionMethod = .purchase
        }
        self.draft = initialDraft
        pristineDraft = initialDraft
        self.analyzer = analyzer
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
        objectAnalysisPhase = .analyzing
        issue = nil

        objectAnalysisTask = Task { [weak self, analyzer] in
            do {
                let suggestion = try await analyzer.analyzeObjectPhoto(data)
                try Task.checkCancellation()
                guard let self else { return }
                objectSuggestion = suggestion
                reapplyAnalysisSuggestions()
                objectAnalysisPhase = .completed
            } catch is CancellationError {
                return
            } catch {
                guard let self, !Task.isCancelled else { return }
                objectAnalysisPhase = .unavailable
                issue = AssetCreationIssue(
                    kind: .objectAnalysis,
                    localizationKey: "asset-flow.error.object-analysis"
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
        invoiceAnalysisPhase = .analyzing
        issue = nil

        invoiceAnalysisTask = Task { [weak self, analyzer] in
            do {
                let suggestion = try await analyzer.analyzeInvoice(
                    document.data,
                    filename: document.filename,
                    mimeType: document.mimeType
                )
                try Task.checkCancellation()
                guard let self else { return }
                invoiceSuggestion = suggestion
                reapplyAnalysisSuggestions()
                invoiceAnalysisPhase = .completed
            } catch is CancellationError {
                return
            } catch {
                guard let self, !Task.isCancelled else { return }
                invoiceAnalysisPhase = .unavailable
                issue = AssetCreationIssue(
                    kind: .invoiceAnalysis,
                    localizationKey: "asset-flow.error.invoice-analysis"
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
        let manuallyConfirmedMetadata: Set<AssetDraft.Field> = [
            .serialNumber,
            .acquisitionMethod,
            .tags,
        ]
        draft.clearSuggestedFields(objectSuggestedFields.union(invoiceSuggestedFields))
        objectSuggestedFields.removeAll()
        invoiceSuggestedFields.removeAll()

        // Keep the capture order deterministic even when the two analyses finish out of order.
        if let objectSuggestion {
            objectSuggestedFields = draft.merge(
                suggestion: objectSuggestion,
                excluding: manuallyConfirmedMetadata
            )
        }

        if let invoiceSuggestion {
            invoiceSuggestedFields = draft.merge(
                suggestion: invoiceSuggestion,
                excluding: objectSuggestedFields.union(manuallyConfirmedMetadata)
            )
        }
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
}
