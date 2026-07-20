import Testing
@testable import KARA

@Suite("Onboarding state")
struct OnboardingFlowTests {
    @Test
    func advanceTraversesExactlyThreeSteps() {
        var state = OnboardingFlowState()

        #expect(state.step == .revelation)
        #expect(state.advance() == .advanced(.organization))
        #expect(state.step == .organization)
        #expect(state.advance() == .advanced(.privacy))
        #expect(state.step == .privacy)
        #expect(state.advance() == .completed)
        #expect(state.step == .privacy)
    }

    @Test
    func buttonAndSwipeUseTheSameSelectionState() {
        var state = OnboardingFlowState()

        state.select(.privacy)
        #expect(state.step == .privacy)
        #expect(state.advance() == .completed)
    }

    @Test
    func reducedMotionUsesStaticMotionProfile() {
        let reduced = OnboardingMotionProfile(reduceMotion: true)
        let standard = OnboardingMotionProfile(reduceMotion: false)

        #expect(!reduced.sceneMotionEnabled)
        #expect(!reduced.parallaxEnabled)
        #expect(reduced.transitionDuration < standard.transitionDuration)
        #expect(standard.sceneMotionEnabled)
        #expect(standard.parallaxEnabled)
    }
}
