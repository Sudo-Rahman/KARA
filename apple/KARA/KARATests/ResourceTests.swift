import Testing
import UIKit

@Suite("Bundled resources")
struct ResourceTests {
    @Test
    @MainActor
    func geologicaFontIsRegistered() {
        #expect(UIFont.familyNames.contains("Geologica"))
    }

    @Test
    @MainActor
    func seamlessOnboardingBackgroundIsBundled() {
        let background = UIImage(named: "OnboardingBackgroundRevelation")

        #expect(background != nil)
        #expect((background?.cgImage?.width ?? 0) >= 2_000)
        #expect((background?.cgImage?.height ?? 0) >= 4_000)
    }

    @Test
    @MainActor
    func assetCategoryArtworkIsBundled() {
        for name in ["AssetKindBar", "AssetKindCoin", "AssetKindJewelry", "AssetKindOther"] {
            let artwork = UIImage(named: name)

            #expect(artwork != nil, "Missing category artwork: \(name)")
            #expect((artwork?.cgImage?.width ?? 0) >= 1_000)
            #expect((artwork?.cgImage?.height ?? 0) >= 1_000)
        }
    }

    @Test
    func cameraUsageDescriptionIsBundled() {
        let description = Bundle.main.object(
            forInfoDictionaryKey: "NSCameraUsageDescription"
        ) as? String

        #expect(!(description ?? "").isEmpty)
    }
}
