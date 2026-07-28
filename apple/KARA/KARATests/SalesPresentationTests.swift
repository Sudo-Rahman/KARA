import Foundation
import Testing
@testable import KARA

@Suite("Sales presentation")
struct SalesPresentationTests {
    @Test("French monetary input keeps decimal precision")
    func parsesLocalizedAmount() {
        let amount = SalesAmountParser.amount(
            from: "3\u{00A0}120,55",
            locale: Locale(identifier: "fr_FR")
        )

        #expect(amount == Decimal(string: "3120.55"))
    }

    @Test("Sale validation rejects fees above gross proceeds")
    func rejectsFeesAboveGrossAmount() {
        #expect(
            SalesFormValidator.validate(
                grossAmount: 100,
                feesAmount: 101,
                quantity: 1,
                heldQuantity: 1
            ) == .feesExceedGrossAmount
        )
    }

    @Test("Sale validation accepts an integer partial sale")
    func acceptsPartialSale() {
        #expect(
            SalesFormValidator.validate(
                grossAmount: Decimal(string: "825.50")!,
                feesAmount: 25,
                quantity: 2,
                heldQuantity: 4
            ) == nil
        )
    }

    @Test("Sale validation compares purchase and sale dates by calendar day")
    func validatesSaleCalendarDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let purchaseDate = calendar.date(
            from: DateComponents(
                year: 2026,
                month: 7,
                day: 20,
                hour: 18
            )
        )!

        #expect(
            SalesFormValidator.validate(
                grossAmount: 100,
                feesAmount: 0,
                quantity: 1,
                heldQuantity: 1,
                soldAt: purchaseDate.addingTimeInterval(-60 * 60),
                purchaseDate: purchaseDate,
                calendar: calendar
            ) == nil
        )
        #expect(
            SalesFormValidator.validate(
                grossAmount: 100,
                feesAmount: 0,
                quantity: 1,
                heldQuantity: 1,
                soldAt: purchaseDate.addingTimeInterval(-24 * 60 * 60),
                purchaseDate: purchaseDate,
                calendar: calendar
            ) == .salePredatesPurchase
        )
    }
}
