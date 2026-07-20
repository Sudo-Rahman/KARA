import Foundation
import Testing
@testable import KARA

@Suite("Application flow")
@MainActor
struct AppFlowTests {
    @Test
    func freshInstallStartsFirstLaunchOnboarding() {
        let defaults = makeDefaults()
        let flow = AppFlow(defaults: defaults, arguments: [])

        #expect(flow.destination == .onboarding(.firstLaunch))
    }

    @Test
    func completedInstallStartsMainApplication() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: AppFlow.completionKey)

        let flow = AppFlow(defaults: defaults, arguments: [])

        #expect(flow.destination == .main)
    }

    @Test
    func resetArgumentClearsCompletion() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: AppFlow.completionKey)

        let flow = AppFlow(
            defaults: defaults,
            arguments: ["-KARAResetOnboarding"]
        )

        #expect(flow.destination == .onboarding(.firstLaunch))
        #expect(!defaults.bool(forKey: AppFlow.completionKey))
    }

    @Test
    func skipPersistsCompletion() {
        let defaults = makeDefaults()
        let flow = AppFlow(defaults: defaults, arguments: [])

        flow.skipOnboarding()

        #expect(flow.destination == .main)
        #expect(defaults.bool(forKey: AppFlow.completionKey))
    }

    @Test
    func replayUsesReplayModeWithoutClearingCompletion() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: AppFlow.completionKey)
        let flow = AppFlow(defaults: defaults, arguments: [])

        flow.replayOnboarding()

        #expect(flow.destination == .onboarding(.replay))
        #expect(defaults.bool(forKey: AppFlow.completionKey))

        flow.finishReplay()

        #expect(flow.destination == .main)
        #expect(defaults.bool(forKey: AppFlow.completionKey))
    }

    private func makeDefaults() -> UserDefaults {
        let suite = "kara.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }
}
