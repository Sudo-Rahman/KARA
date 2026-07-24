import Foundation
import Testing
@testable import KARA

@Suite("Portfolio history chart selection")
struct PortfolioHistorySelectionTests {
    @Test("Returns nil when there are no history points")
    func emptyHistory() {
        #expect(PortfolioHistorySelection.nearestPoint(to: .now, in: []) == nil)
    }

    @Test("Clamps dates outside the history to the nearest endpoint")
    func clampsToEndpoints() throws {
        let points = makePoints(dayOffsets: [0, 10, 20])

        let before = try #require(PortfolioHistorySelection.nearestPoint(
            to: date(dayOffset: -100),
            in: points
        ))
        let after = try #require(PortfolioHistorySelection.nearestPoint(
            to: date(dayOffset: 100),
            in: points
        ))

        #expect(before.date == points.first?.date)
        #expect(after.date == points.last?.date)
    }

    @Test("Returns the point closest to the touched date")
    func nearestPoint() throws {
        let points = makePoints(dayOffsets: [0, 10, 20])

        let selection = try #require(PortfolioHistorySelection.nearestPoint(
            to: date(dayOffset: 7),
            in: points
        ))

        #expect(selection.date == date(dayOffset: 10))
    }

    @Test("Breaks equal-distance ties toward the most recent point")
    func tieBreaksTowardRecentPoint() throws {
        let points = makePoints(dayOffsets: [0, 10])

        let selection = try #require(PortfolioHistorySelection.nearestPoint(
            to: date(dayOffset: 5),
            in: points
        ))

        #expect(selection.date == date(dayOffset: 10))
    }

    private func makePoints(dayOffsets: [Int]) -> [PortfolioHistoryPoint] {
        dayOffsets.map { offset in
            PortfolioHistoryPoint(
                date: date(dayOffset: offset),
                valueEUR: Decimal(offset * 100),
                valuedRecordCount: 1,
                totalHeldRecordCount: 1,
                isCurrent: offset == dayOffsets.last
            )
        }
    }

    private func date(dayOffset: Int) -> Date {
        Calendar(identifier: .gregorian).date(
            byAdding: .day,
            value: dayOffset,
            to: Date(timeIntervalSince1970: 1_700_000_000)
        )!
    }
}
