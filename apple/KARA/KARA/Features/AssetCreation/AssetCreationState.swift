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
    private enum AnalysisTarget: CaseIterable {
        case objectPhoto
        case invoice

        var slotKeyPath: ReferenceWritableKeyPath<AssetCreationState, AnalysisSlot> {
            switch self {
            case .objectPhoto: \.objectAnalysis
            case .invoice: \.invoiceAnalysis
            }
        }

        var issueKind: AssetCreationIssue.Kind {
            switch self {
            case .objectPhoto: .objectAnalysis
            case .invoice: .invoiceAnalysis
            }
        }
    }

    private struct AnalysisSlot {
        var phase: AssetAnalysisPhase = .idle
        var suggestion: AssetAnalysisSuggestion?
        var task: Task<Void, Never>?

        mutating func cancel() {
            task?.cancel()
            task = nil
        }

        @discardableResult
        mutating func replace(isEnabled: Bool) -> Bool {
            cancel()
            suggestion = nil
            phase = isEnabled ? .analyzing : .idle
            return isEnabled
        }

        mutating func attach(_ task: Task<Void, Never>) {
            self.task = task
        }

        mutating func remove() {
            replace(isEnabled: false)
        }

        mutating func complete(with suggestion: AssetAnalysisSuggestion) {
            task = nil
            self.suggestion = suggestion
            phase = .completed
        }

        mutating func fail(with error: AssetAnalysisError) {
            task = nil
            phase = .failed(error)
        }

        mutating func disable() {
            remove()
        }
    }

    private(set) var step: AssetCreationStep = .objectPhoto
    var draft: AssetDraft
    private(set) var objectPhotoData: Data?
    private(set) var invoiceDocument: PreparedMediaDocument?
    private var objectAnalysis = AnalysisSlot()
    private var invoiceAnalysis = AnalysisSlot()
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
    private var analysisSuggestedFields: Set<AssetDraft.Field> = []

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

    var objectAnalysisPhase: AssetAnalysisPhase {
        objectAnalysis.phase
    }

    var invoiceAnalysisPhase: AssetAnalysisPhase {
        invoiceAnalysis.phase
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
        objectPhotoData = data
        replaceAnalysis(for: .objectPhoto) { [analyzer] in
            try await analyzer.analyzeObjectPhoto(data)
        }
    }

    func removeObjectPhoto() {
        objectPhotoData = nil
        removeAnalysis(for: .objectPhoto)
    }

    func setInvoiceDocument(_ document: PreparedMediaDocument) {
        invoiceDocument = document
        replaceAnalysis(for: .invoice) { [analyzer] in
            try await analyzer.analyzeInvoice(document)
        }
    }

    func removeInvoiceDocument() {
        invoiceDocument = nil
        removeAnalysis(for: .invoice)
    }

    private func replaceAnalysis(
        for target: AnalysisTarget,
        operation: @escaping @Sendable () async throws -> AssetAnalysisSuggestion
    ) {
        let shouldStart = withAnalysisSlot(for: target) {
            $0.replace(isEnabled: analysisPreferences.isEnabled)
        }
        reapplyAnalysisSuggestions()
        issue = nil

        guard shouldStart else { return }
        let task = startAnalysis(for: target, operation: operation)
        withAnalysisSlot(for: target) { $0.attach(task) }
    }

    private func removeAnalysis(for target: AnalysisTarget) {
        withAnalysisSlot(for: target) { $0.remove() }
        reapplyAnalysisSuggestions()
        clearAnalysisIssue(for: target)
    }

    private func startAnalysis(
        for target: AnalysisTarget,
        operation: @escaping @Sendable () async throws -> AssetAnalysisSuggestion
    ) -> Task<Void, Never> {
        Task { [weak self] in
            do {
                let suggestion = try await operation()
                try Task.checkCancellation()
                self?.completeAnalysis(suggestion, for: target)
            } catch is CancellationError {
                return
            } catch let error as AssetAnalysisError {
                guard !Task.isCancelled else { return }
                self?.failAnalysis(error, for: target)
            } catch {
                guard !Task.isCancelled else { return }
                self?.failAnalysis(.technicalFailure, for: target)
            }
        }
    }

    private func completeAnalysis(
        _ suggestion: AssetAnalysisSuggestion,
        for target: AnalysisTarget
    ) {
        withAnalysisSlot(for: target) { $0.complete(with: suggestion) }
        reapplyAnalysisSuggestions()
    }

    private func failAnalysis(_ error: AssetAnalysisError, for target: AnalysisTarget) {
        withAnalysisSlot(for: target) { $0.fail(with: error) }
        issue = AssetCreationIssue(
            kind: target.issueKind,
            localizationKey: Self.localizationKey(for: error)
        )
    }

    private func clearAnalysisIssue(for target: AnalysisTarget) {
        if issue?.kind == target.issueKind {
            issue = nil
        }
    }

    @discardableResult
    private func withAnalysisSlot<Result>(
        for target: AnalysisTarget,
        _ update: (inout AnalysisSlot) -> Result
    ) -> Result {
        update(&self[keyPath: target.slotKeyPath])
    }

    private func reapplyAnalysisSuggestions() {
        draft.clearSuggestedFields(analysisSuggestedFields)
        analysisSuggestedFields.removeAll()

        let resolved = AssetAnalysisSuggestionResolver.resolve(
            objectPhoto: objectAnalysis.suggestion,
            invoice: invoiceAnalysis.suggestion,
            preserving: draft
        )
        analysisSuggestedFields = draft.merge(suggestion: resolved)
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
        for target in AnalysisTarget.allCases {
            withAnalysisSlot(for: target) { slot in
                slot.cancel()
                if slot.phase == .analyzing {
                    slot.phase = .idle
                }
            }
        }
    }

    func analysisPreferenceDidChange() {
        guard !analysisPreferences.isEnabled else { return }
        for target in AnalysisTarget.allCases {
            withAnalysisSlot(for: target) { $0.disable() }
        }
        reapplyAnalysisSuggestions()
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
        case .invalidResponse, .technicalFailure:
            "asset-flow.error.analysis-technical"
        }
    }
}
