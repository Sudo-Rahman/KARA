import Testing
@testable import KARA

@Suite("Asset creation navigation")
@MainActor
struct AssetCreationNavigationTests {
    @Test("The guided flow advances through six ordered native destinations")
    func advancesThroughTheGuidedFlow() {
        let router = AssetCreationRouter()

        #expect(router.currentStep == .objectPhoto)
        #expect(router.path.isEmpty)

        router.advance(to: .invoice)
        router.advance(to: .classification)
        router.advance(to: .characteristics)
        router.advance(to: .purchase)
        router.advance(to: .summary)

        #expect(router.currentStep == .summary)
        #expect(router.path == [.invoice, .classification, .characteristics, .purchase, .summary])

        for expectedStep in [
            AssetCreationStep.purchase,
            .characteristics,
            .classification,
            .invoice,
            .objectPhoto,
        ] {
            router.goBack()
            #expect(router.currentStep == expectedStep)
        }

        #expect(router.path.isEmpty)

        router.goBack()
        #expect(router.currentStep == .objectPhoto)
        #expect(router.path.isEmpty)
    }

    @Test("The router rejects skipped, duplicate, and reverse destinations")
    func rejectsOutOfOrderDestinations() {
        let router = AssetCreationRouter()

        router.advance(to: .classification)
        #expect(router.path.isEmpty)

        router.advance(to: .invoice)
        router.advance(to: .invoice)
        router.advance(to: .characteristics)
        #expect(router.path == [.invoice])

        router.advance(to: .classification)
        router.advance(to: .objectPhoto)
        #expect(router.path == [.invoice, .classification])
    }

    @Test("Editing from the summary returns to characteristics without losing prior history")
    func returnsToCharacteristicsForEditing() {
        let router = AssetCreationRouter(
            path: [.invoice, .classification, .characteristics, .purchase, .summary]
        )

        router.editCharacteristics()

        #expect(router.currentStep == .characteristics)
        #expect(router.path == [.invoice, .classification, .characteristics])

        router.advance(to: .purchase)
        router.advance(to: .summary)

        #expect(router.currentStep == .summary)
        #expect(router.path == [.invoice, .classification, .characteristics, .purchase, .summary])
    }
}
