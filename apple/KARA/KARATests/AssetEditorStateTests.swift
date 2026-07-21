import Foundation
import Testing
@testable import KARA

@Suite("Asset editor state")
struct AssetEditorStateTests {
    @Test
    func restoringAnEditedValueClearsUnsavedChanges() {
        let original = AssetDraft(name: "Lingot", category: .bar)
        var state = AssetEditorDraftState(draft: original)

        #expect(!state.hasUnsavedChanges)

        state.draft.name = "Lingot numéroté"
        #expect(state.hasUnsavedChanges)

        state.draft.name = original.name
        #expect(!state.hasUnsavedChanges)
    }

    @Test
    func tagsAreTrimmedAndDeduplicatedForPersistence() {
        var state = AssetEditorDraftState(
            draft: AssetDraft(name: "Bracelet", category: .jewelry)
        )

        state.setTags(from: " Long terme,  cadeau ; long TERME\nAssuré ")

        #expect(state.draft.tags == ["Long terme", "cadeau", "Assuré"])
        #expect(state.hasUnsavedChanges)
    }

    @Test
    func changingCurrencyPreservesTheEnteredMajorAmount() {
        var state = AssetEditorDraftState(
            draft: AssetDraft(
                name: "Pièce",
                category: .coin,
                pricePaidMinorUnits: 123_45,
                currencyCode: "EUR"
            )
        )

        state.setCurrency(.swissFranc)

        #expect(state.draft.currencyCode == "CHF")
        #expect(state.draft.pricePaidMinorUnits == 123_45)
        #expect(state.priceAmount == Decimal(string: "123.45"))
    }

    @Test
    func selectingAPresetSynchronizesItsCatalogFields() throws {
        let preset = try #require(AssetCatalog.preset(id: "gold-bar-20g"))
        var state = AssetEditorDraftState(
            draft: AssetDraft(name: "Ancien nom", category: .custom)
        )

        state.apply(preset: preset, displayName: "20 g gold bar")

        #expect(state.draft.presetID == preset.id)
        #expect(state.draft.name == "20 g gold bar")
        #expect(state.draft.category == .bar)
        #expect(state.draft.metal == .gold)
        #expect(state.draft.weightGrams == 20)
        #expect(state.draft.finenessPermille == 999.9)
    }

    @Test
    func changingClassificationDetachesAnIncompatiblePresetWithoutErasingFields() {
        var state = AssetEditorDraftState(
            draft: AssetDraft(
                name: "Lingotin personnel",
                category: .bar,
                presetID: "gold-bar-20g",
                metal: .gold,
                weightGrams: 20
            )
        )

        state.setCategory(.custom)

        #expect(state.draft.category == .custom)
        #expect(state.draft.presetID == nil)
        #expect(state.draft.name == "Lingotin personnel")
        #expect(state.draft.metal == .gold)
        #expect(state.draft.weightGrams == 20)
    }
}
