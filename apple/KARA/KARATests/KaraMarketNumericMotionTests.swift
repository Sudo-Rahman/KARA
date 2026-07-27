import Testing
@testable import KARA

@Suite("Market numeric motion")
struct KaraMarketNumericMotionTests {
    @Test("Uses targeted rolling when motion is allowed")
    func usesRollingByDefault() {
        #expect(KaraMarketNumericMotion.style(reduceMotion: false) == .rolling)
    }

    @Test("Uses a fade when Reduce Motion is enabled")
    func usesFadeForReducedMotion() {
        #expect(KaraMarketNumericMotion.style(reduceMotion: true) == .fading)
    }
}
