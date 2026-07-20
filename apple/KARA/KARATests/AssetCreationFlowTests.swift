import Foundation
import Testing
@testable import KARA

@Suite("Asset creation flow")
@MainActor
struct AssetCreationFlowTests {
    @Test
    func captureStepsCanBeSkippedAndDraftValidityUpdates() {
        let state = makeState()

        #expect(state.step == .objectPhoto)

        state.skipCurrentStep()
        #expect(state.step == .invoice)

        state.skipCurrentStep()
        #expect(state.step == .classification)

        #expect(!state.canAdvanceFromDetails)

        state.update(\.name, to: "Lingotin 10 g", field: .name)
        state.update(\.category, to: .custom, field: .category)

        #expect(state.canAdvanceFromDetails)
    }

    @Test
    func analysisCompletesEmptyFieldsWithoutReplacingManualEdits() async {
        let analyzer = SuggestedNameAnalyzer()
        let state = AssetCreationState(
            analyzer: analyzer,
            saver: FailingSaver()
        )
        state.update(\.name, to: "Nom choisi", field: .name)

        state.setObjectPhoto(Data([0x01]))
        await waitForAnalysis(in: state)

        #expect(state.objectAnalysisPhase == .completed)
        #expect(state.draft.name == "Nom choisi")
        #expect(state.draft.category == .custom)
    }

    @Test
    func replacingMediaReplacesOnlyValuesSuggestedByThePreviousMedia() async {
        let analyzer = SequencedAnalyzer(
            objectSuggestions: [
                AssetAnalysisSuggestion(name: "Ancien objet", category: .bar, metal: .gold),
                AssetAnalysisSuggestion(name: "Nouvel objet", category: .coin, metal: .silver),
            ],
            invoiceSuggestions: [
                AssetAnalysisSuggestion(sellerName: "Ancien vendeur", invoiceNumber: "OLD-1"),
                AssetAnalysisSuggestion(sellerName: "Nouveau vendeur", invoiceNumber: "NEW-2"),
            ]
        )
        let state = AssetCreationState(analyzer: analyzer, saver: FailingSaver())

        state.setObjectPhoto(Data([0x01]))
        await waitForAnalysis(in: state)
        #expect(state.draft.name == "Ancien objet")

        state.setObjectPhoto(Data([0x02]))
        await waitForAnalysis(in: state)
        #expect(state.draft.name == "Nouvel objet")
        #expect(state.draft.category == .coin)
        #expect(state.draft.metal == .silver)

        state.setInvoiceDocument(document(named: "ancienne.pdf"))
        await waitForInvoiceAnalysis(in: state)
        #expect(state.draft.sellerName == "Ancien vendeur")

        state.setInvoiceDocument(document(named: "nouvelle.pdf"))
        await waitForInvoiceAnalysis(in: state)
        #expect(state.draft.sellerName == "Nouveau vendeur")
        #expect(state.draft.invoiceNumber == "NEW-2")
    }

    @Test
    func replacingMediaNeverClearsAValueEditedByTheUser() async {
        let analyzer = SequencedAnalyzer(
            objectSuggestions: [
                AssetAnalysisSuggestion(name: "Nom détecté"),
                AssetAnalysisSuggestion(name: "Autre nom détecté"),
            ]
        )
        let state = AssetCreationState(analyzer: analyzer, saver: FailingSaver())

        state.setObjectPhoto(Data([0x01]))
        await waitForAnalysis(in: state)
        state.update(\.name, to: "Nom choisi", field: .name)

        state.setObjectPhoto(Data([0x02]))
        await waitForAnalysis(in: state)

        #expect(state.draft.name == "Nom choisi")
    }

    @Test
    func replacingAndRemovingObjectPhotoReappliesOverlappingSuggestions() async {
        let analyzer = SequencedAnalyzer(
            objectSuggestions: [
                AssetAnalysisSuggestion(name: "Ancienne photo", quantity: 1, currencyCode: "EUR"),
                AssetAnalysisSuggestion(name: "Nouvelle photo", quantity: 4, currencyCode: "GBP"),
            ],
            invoiceSuggestions: [
                AssetAnalysisSuggestion(name: "Nom de la facture", quantity: 3, currencyCode: "CHF")
            ]
        )
        let state = AssetCreationState(analyzer: analyzer, saver: FailingSaver())

        state.setObjectPhoto(Data([0x01]))
        await waitForAnalysis(in: state)
        state.setInvoiceDocument(document(named: "facture.pdf"))
        await waitForInvoiceAnalysis(in: state)

        #expect(state.draft.name == "Ancienne photo")
        #expect(state.draft.quantity == 1)
        #expect(state.draft.currencyCode == "EUR")

        state.setObjectPhoto(Data([0x02]))
        await waitForAnalysis(in: state)

        #expect(state.draft.name == "Nouvelle photo")
        #expect(state.draft.quantity == 4)
        #expect(state.draft.currencyCode == "GBP")

        state.removeObjectPhoto()

        #expect(state.draft.name == "Nom de la facture")
        #expect(state.draft.quantity == 3)
        #expect(state.draft.currencyCode == "CHF")
    }

    @Test
    func invoiceCompletingFirstKeepsPhotoPriorityAndItsReplacementAvailable() async {
        let analyzer = SequencedAnalyzer(
            objectSuggestions: [AssetAnalysisSuggestion(name: "Nom de la photo")],
            invoiceSuggestions: [
                AssetAnalysisSuggestion(name: "Ancienne facture"),
                AssetAnalysisSuggestion(name: "Nouvelle facture"),
            ]
        )
        let state = AssetCreationState(analyzer: analyzer, saver: FailingSaver())

        state.setInvoiceDocument(document(named: "ancienne.pdf"))
        await waitForInvoiceAnalysis(in: state)
        #expect(state.draft.name == "Ancienne facture")

        state.setObjectPhoto(Data([0x01]))
        await waitForAnalysis(in: state)
        #expect(state.draft.name == "Nom de la photo")

        state.setInvoiceDocument(document(named: "nouvelle.pdf"))
        await waitForInvoiceAnalysis(in: state)
        #expect(state.draft.name == "Nom de la photo")

        state.removeObjectPhoto()
        #expect(state.draft.name == "Nouvelle facture")
    }

    @Test
    func analysisNeverReplacesManuallyConfirmedQuantityAndCurrencyDefaults() async {
        let analyzer = SequencedAnalyzer(
            objectSuggestions: [AssetAnalysisSuggestion(quantity: 4, currencyCode: "USD")]
        )
        let state = AssetCreationState(analyzer: analyzer, saver: FailingSaver())
        state.update(\.quantity, to: 1, field: .quantity)
        state.updateCurrencyCode("EUR")

        state.setObjectPhoto(Data([0x01]))
        await waitForAnalysis(in: state)

        #expect(state.draft.quantity == 1)
        #expect(state.draft.currencyCode == "EUR")
    }

    @Test
    func clearingAPresetRemovesItsDerivedSpecifications() throws {
        let state = makeState()
        let preset = try #require(AssetCatalog.preset(id: "gold-bar-10g"))

        state.applyPreset(preset)
        state.clearPresetSelection()

        #expect(state.draft.presetID == nil)
        #expect(state.draft.name.isEmpty)
        #expect(state.draft.weightGrams == nil)
        #expect(state.draft.metalKarat == nil)
        #expect(state.draft.finenessPermille == nil)
    }

    @Test
    func failedSaveRetainsTheDraftAndPreparedAttachmentsForRetry() {
        let saver = RecordingFailingSaver()
        let state = AssetCreationState(
            analyzer: ImmediateAnalyzer(),
            saver: saver
        )
        state.update(\.name, to: "Souverain", field: .name)
        state.update(\.category, to: .custom, field: .category)
        state.setObjectPhoto(Data([0xFF, 0xD8, 0xFF]))

        let saved = state.save()

        #expect(saved == nil)
        #expect(state.draft.name == "Souverain")
        #expect(state.objectPhotoData == Data([0xFF, 0xD8, 0xFF]))
        #expect(saver.receivedAttachments?.map(\.kind) == [.objectPhoto])
        #expect(state.issue?.kind == .save)
    }

    @Test(
        "Changing between supported currencies preserves the displayed decimal amount",
        arguments: SupportedAssetCurrency.allCases
    )
    func changingCurrencyPreservesTheDisplayedDecimalAmount(
        currency: SupportedAssetCurrency
    ) {
        let state = AssetCreationState(
            draft: AssetDraft(pricePaidMinorUnits: 1_234, currencyCode: "EUR"),
            analyzer: ImmediateAnalyzer(),
            saver: FailingSaver()
        )

        state.updateCurrencyCode(currency.rawValue)

        #expect(state.draft.currencyCode == currency.rawValue)
        #expect(state.draft.pricePaidMinorUnits == 1_234)
        #expect(state.draft.manuallyEditedFields.contains(.currencyCode))
        #expect(state.draft.manuallyEditedFields.contains(.pricePaidMinorUnits))
    }

    @Test
    func cancellingTheFlowCancelsInFlightAnalysis() async {
        let analyzer = CancellableAnalyzer()
        let state = AssetCreationState(
            analyzer: analyzer,
            saver: FailingSaver()
        )
        state.setObjectPhoto(Data([0x01]))
        await Task.yield()

        state.cancelAllWork()
        for _ in 0 ..< 100 {
            if await analyzer.wasCancelled() { break }
            await Task.yield()
        }

        let wasCancelled = await analyzer.wasCancelled()
        #expect(wasCancelled)
        #expect(state.objectAnalysisPhase == .idle)
    }

    private func makeState() -> AssetCreationState {
        AssetCreationState(
            analyzer: ImmediateAnalyzer(),
            saver: FailingSaver()
        )
    }

    private func waitForAnalysis(in state: AssetCreationState) async {
        for _ in 0 ..< 100 where state.objectAnalysisPhase == .analyzing {
            await Task.yield()
        }
    }

    private func waitForInvoiceAnalysis(in state: AssetCreationState) async {
        for _ in 0 ..< 100 where state.invoiceAnalysisPhase == .analyzing {
            await Task.yield()
        }
    }

    private func document(named filename: String) -> PreparedMediaDocument {
        PreparedMediaDocument(
            data: Data([0x25, 0x50, 0x44, 0x46]),
            filename: filename,
            mimeType: "application/pdf",
            pageCount: 1
        )
    }
}

private struct ImmediateAnalyzer: AssetAnalyzing {
    func analyzeObjectPhoto(_ data: Data) async throws -> AssetAnalysisSuggestion {
        AssetAnalysisSuggestion()
    }

    func analyzeInvoice(
        _ data: Data,
        filename: String,
        mimeType: String
    ) async throws -> AssetAnalysisSuggestion {
        AssetAnalysisSuggestion()
    }
}

private struct SuggestedNameAnalyzer: AssetAnalyzing {
    func analyzeObjectPhoto(_ data: Data) async throws -> AssetAnalysisSuggestion {
        AssetAnalysisSuggestion(name: "Nom IA", category: .custom)
    }

    func analyzeInvoice(
        _ data: Data,
        filename: String,
        mimeType: String
    ) async throws -> AssetAnalysisSuggestion {
        AssetAnalysisSuggestion()
    }
}

private actor SequencedAnalyzer: AssetAnalyzing {
    private var objectSuggestions: [AssetAnalysisSuggestion]
    private var invoiceSuggestions: [AssetAnalysisSuggestion]

    init(
        objectSuggestions: [AssetAnalysisSuggestion] = [],
        invoiceSuggestions: [AssetAnalysisSuggestion] = []
    ) {
        self.objectSuggestions = objectSuggestions
        self.invoiceSuggestions = invoiceSuggestions
    }

    func analyzeObjectPhoto(_ data: Data) async throws -> AssetAnalysisSuggestion {
        guard !objectSuggestions.isEmpty else { return AssetAnalysisSuggestion() }
        return objectSuggestions.removeFirst()
    }

    func analyzeInvoice(
        _ data: Data,
        filename: String,
        mimeType: String
    ) async throws -> AssetAnalysisSuggestion {
        guard !invoiceSuggestions.isEmpty else { return AssetAnalysisSuggestion() }
        return invoiceSuggestions.removeFirst()
    }
}

private actor CancellableAnalyzer: AssetAnalyzing {
    private var cancelled = false

    func analyzeObjectPhoto(_ data: Data) async throws -> AssetAnalysisSuggestion {
        do {
            try await Task.sleep(for: .seconds(60))
            return AssetAnalysisSuggestion()
        } catch is CancellationError {
            cancelled = true
            throw CancellationError()
        }
    }

    func analyzeInvoice(
        _ data: Data,
        filename: String,
        mimeType: String
    ) async throws -> AssetAnalysisSuggestion {
        AssetAnalysisSuggestion()
    }

    func wasCancelled() -> Bool {
        cancelled
    }
}

@MainActor
private struct FailingSaver: AssetSaving {
    func save(
        draft: AssetDraft,
        attachments: [AssetAttachmentPayload]
    ) throws -> Asset {
        throw TestFailure.expected
    }
}

@MainActor
private final class RecordingFailingSaver: AssetSaving {
    private(set) var receivedAttachments: [AssetAttachmentPayload]?

    func save(
        draft: AssetDraft,
        attachments: [AssetAttachmentPayload]
    ) throws -> Asset {
        receivedAttachments = attachments
        throw TestFailure.expected
    }
}

private enum TestFailure: Error {
    case expected
}
