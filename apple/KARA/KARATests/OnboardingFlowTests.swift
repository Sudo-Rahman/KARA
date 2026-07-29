import Testing
@testable import KARA

@Suite("Onboarding state")
struct OnboardingFlowTests {
    @Test
    func advanceTraversesExactlyFiveSteps() {
        var state = OnboardingFlowState()

        #expect(state.step == .revelation)
        #expect(state.advance() == .advanced(.inventory))
        #expect(state.step == .inventory)
        #expect(state.advance() == .advanced(.valuation))
        #expect(state.step == .valuation)
        #expect(state.advance() == .advanced(.permissions))
        #expect(state.step == .permissions)
        #expect(state.advance() == .advanced(.intelligence))
        #expect(state.step == .intelligence)
        #expect(state.advance() == .completed)
        #expect(state.step == .intelligence)
    }

    @Test
    func buttonAndSwipeUseTheSameSelectionState() {
        var state = OnboardingFlowState()

        state.select(.intelligence)
        #expect(state.step == .intelligence)
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
