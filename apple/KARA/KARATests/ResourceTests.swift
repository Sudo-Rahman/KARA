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
}
