import Foundation
import Testing
@testable import KARA

@Suite("KARA widget background refresh schedule")
struct KaraWidgetBackgroundRefreshScheduleTests {
    private let policy = KaraAppBackgroundRefreshSchedulePolicy(
        configuredWidgetInterval: 60 * 60,
        unconfiguredWidgetInterval: 12 * 60 * 60
    )
    private let now = Date(timeIntervalSince1970: 1_785_000_000)

    @Test("A configured widget requests an hourly opportunity")
    func schedulesConfiguredWidgetHourly() {
        #expect(
            policy.decision(
                hasFrequentWork: true,
                pendingEarliestBeginDate: nil,
                now: now
            ) == .submit(earliestBeginDate: now.addingTimeInterval(60 * 60))
        )
    }

    @Test("Discovery remains infrequent when no widget is configured")
    func schedulesUnconfiguredWidgetDiscovery() {
        #expect(
            policy.decision(
                hasFrequentWork: false,
                pendingEarliestBeginDate: nil,
                now: now
            ) == .submit(earliestBeginDate: now.addingTimeInterval(12 * 60 * 60))
        )
    }

    @Test("An earlier pending opportunity is preserved")
    func preservesEarlierPendingRequest() {
        #expect(
            policy.decision(
                hasFrequentWork: true,
                pendingEarliestBeginDate: now.addingTimeInterval(30 * 60),
                now: now
            ) == .keepExisting
        )
    }

    @Test("A needlessly late pending opportunity is replaced")
    func replacesLaterPendingRequest() {
        #expect(
            policy.decision(
                hasFrequentWork: true,
                pendingEarliestBeginDate: now.addingTimeInterval(3 * 60 * 60),
                now: now
            ) == .submit(earliestBeginDate: now.addingTimeInterval(60 * 60))
        )
    }

    @Test("A completed run can safely downgrade to discovery cadence")
    func forceReplacesEarlierRequestWhenNoWorkRemains() {
        #expect(
            policy.decision(
                hasFrequentWork: false,
                pendingEarliestBeginDate: now.addingTimeInterval(30 * 60),
                now: now,
                forceReplaceExisting: true
            ) == .submit(earliestBeginDate: now.addingTimeInterval(12 * 60 * 60))
        )
    }
}
