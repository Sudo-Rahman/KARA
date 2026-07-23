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
    @MainActor
    func assetCategoryHeroArtworkIsBundledAndPanoramic() {
        let names = [
            "AssetKindBarHero",
            "AssetKindCoinHero",
            "AssetKindJewelryHero",
            "AssetKindOtherHero",
        ]

        for name in names {
            let artwork = UIImage(named: name)
            let width = artwork?.cgImage?.width ?? 0
            let height = artwork?.cgImage?.height ?? 0

            #expect(artwork != nil, "Missing category hero artwork: \(name)")
            #expect(width >= 1_500, "Hero artwork is too narrow: \(name)")
            #expect(height >= 800, "Hero artwork is too short: \(name)")
            #expect(Double(width) / Double(max(height, 1)) > 1.7, "Hero artwork is not panoramic: \(name)")
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
