import Foundation
import Testing
@testable import KARA

@Suite("Market data DTOs")
struct MarketDataDTOTests {
    @Test("A schema-v1 spot payload preserves decimal precision")
    func decodesSpotPayload() throws {
        let payload = Data(#"{"schemaVersion":1,"metal":"XAU","currency":"EUR","price":"3558.900966","unit":{"code":"troy_ounce","grams":"31.1034768"},"sourceUpdatedAt":"2026-07-21T09:45:33Z"}"#.utf8)

        let quote = try MarketJSON.decoder.decode(SpotQuote.self, from: payload)

        #expect(quote.schemaVersion == 1)
        #expect(quote.metal == .gold)
        #expect(quote.currency == .eur)
        #expect(quote.price == Decimal(string: "3558.900966"))
        #expect(quote.unit == MarketUnit(code: .troyOunce, grams: Decimal(string: "31.1034768")!))
        #expect(quote.sourceUpdatedAt == Date(timeIntervalSince1970: 1_784_627_133))
        #expect(quote.pricePerGram > Decimal(string: "114.42")!)
        #expect(quote.pricePerGram < Decimal(string: "114.43")!)
    }

    @Test("A schema-v1 monthly payload exposes prices by metal, currency, and month")
    func decodesMonthlyPayload() throws {
        let payload = Data(#"{"schemaVersion":1,"datasetId":"precious-metals-monthly","frequency":"monthly","priceKind":"monthly_average","unit":{"code":"troy_ounce","grams":"31.1034768"},"methodology":{"nominal":true,"currencyConversion":"ratio_of_monthly_average_rates","roundingDecimals":6,"roundingMode":"half_even"},"sources":[],"series":[{"metal":"XAU","observations":[{"month":"2026-05","prices":{"USD":"4578.456923","EUR":"3922.262420"}}]}]}"#.utf8)

        let dataset = try MarketJSON.decoder.decode(MonthlyDataset.self, from: payload).validated()

        #expect(dataset.price(for: .gold, currency: .eur, month: "2026-05") == Decimal(string: "3922.262420"))
        #expect(dataset.price(for: .gold, currency: .usd, month: "2026-05") == Decimal(string: "4578.456923"))
        #expect(dataset.price(for: .silver, currency: .eur, month: "2026-05") == nil)
    }

    @Test("The manifest decodes its fractional timestamp and data version")
    func decodesManifest() throws {
        let payload = Data(#"{"schemaVersion":1,"datasetId":"precious-metals-monthly","dataVersion":"abc123","publishedAt":"2026-07-20T11:08:39.000Z","metals":["XAU","XAG","XPT","XPD"],"coverage":{"from":"1987-01","through":"2026-05"},"currencies":{"EUR":{"from":"1999-01","through":"2026-05"}},"file":{"url":"/v1/metals-monthly.json","sha256":"abc123","bytes":408442}}"#.utf8)

        let manifest = try MarketJSON.decoder.decode(MarketManifest.self, from: payload).validated()

        #expect(manifest.dataVersion == "abc123")
        #expect(manifest.metals == MarketMetal.allCases)
        #expect(manifest.publishedAt == Date(timeIntervalSince1970: 1_784_545_719))
    }

    @Test("Unknown schema versions are rejected before entering the store")
    func rejectsUnknownSchemaVersion() throws {
        let payload = Data(#"{"schemaVersion":2,"metal":"XAU","currency":"EUR","price":"3558.900966","unit":{"code":"troy_ounce","grams":"31.1034768"},"sourceUpdatedAt":"2026-07-21T09:45:33Z"}"#.utf8)
        let quote = try MarketJSON.decoder.decode(SpotQuote.self, from: payload)

        #expect(throws: MarketPayloadError.unsupportedSchemaVersion(2)) {
            try quote.validated()
        }
    }
}
