import Testing
import UIKit

@Suite("Bundled resources")
struct ResourceTests {
    @Test
    @MainActor
    func geologicaFontIsRegistered() {
        #expect(UIFont.familyNames.contains("Geologica"))
    }
}
