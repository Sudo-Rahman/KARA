import Foundation
import FoundationModels
import UIKit
import Vision

@Generable
nonisolated struct GeneratedAssetAnalysis {
    @Guide(description: "Concise display name of the asset, without inventing a brand or reference.")
    var name: String?

    @Guide(description: "One of: bar, coin, jewelry, custom.")
    var category: String?

    @Guide(description: "A stable preset identifier from the supplied catalog, or nil when there is no exact match.")
    var presetID: String?

    @Guide(description: "Number of identical assets purchased, when explicitly visible.")
    var quantity: Int?

    @Guide(description: "Purchase date in YYYY-MM-DD format, only when explicitly visible.")
    var purchaseDateISO8601: String?

    @Guide(description: "One of: gold, silver, platinum, palladium, other.")
    var metal: String?

    @Guide(description: "Gross weight in grams, without a unit suffix.")
    var weightGrams: Double?

    @Guide(description: "Metal purity in karats from 1 through 24.")
    var metalKarat: Int?

    @Guide(description: "Metal fineness in parts per thousand from greater than 0 through 1000.")
    var finenessPermille: Double?

    @Guide(description: "Gemstone weight in carats, not metal purity.")
    var gemstoneCaratWeight: Double?

    @Guide(description: "Gemstone clarity grade such as VS1, only when explicitly visible.")
    var gemstoneClarity: String?

    @Guide(description: "Total price paid in the major currency unit, without a currency symbol.")
    var pricePaidAmount: Decimal?

    @Guide(description: "One of the supported purchase currencies: EUR, USD, CHF, GBP.")
    var currencyCode: String?

    @Guide(description: "Seller or merchant name, only when explicitly visible.")
    var sellerName: String?

    @Guide(description: "Storage location only when explicitly present; never infer one.")
    var storageLocationName: String?

    @Guide(description: "Invoice identifier or number, only when explicitly visible.")
    var invoiceNumber: String?

    init(
        name: String? = nil,
        category: String? = nil,
        presetID: String? = nil,
        quantity: Int? = nil,
        purchaseDateISO8601: String? = nil,
        metal: String? = nil,
        weightGrams: Double? = nil,
        metalKarat: Int? = nil,
        finenessPermille: Double? = nil,
        gemstoneCaratWeight: Double? = nil,
        gemstoneClarity: String? = nil,
        pricePaidAmount: Decimal? = nil,
        currencyCode: String? = nil,
        sellerName: String? = nil,
        storageLocationName: String? = nil,
        invoiceNumber: String? = nil
    ) {
        self.name = name
        self.category = category
        self.presetID = presetID
        self.quantity = quantity
        self.purchaseDateISO8601 = purchaseDateISO8601
        self.metal = metal
        self.weightGrams = weightGrams
        self.metalKarat = metalKarat
        self.finenessPermille = finenessPermille
        self.gemstoneCaratWeight = gemstoneCaratWeight
        self.gemstoneClarity = gemstoneClarity
        self.pricePaidAmount = pricePaidAmount
        self.currencyCode = currencyCode
        self.sellerName = sellerName
        self.storageLocationName = storageLocationName
        self.invoiceNumber = invoiceNumber
    }
}

nonisolated struct FoundationModelAssetAnalyzer: AssetModelAnalyzing {
    func analyze(
        _ input: AssetModelAnalysisInput,
        using route: AssetIntelligenceModelRoute
    ) async throws -> AssetAnalysisSuggestion {
        do {
            switch route {
            case .onDevice:
                return try await analyze(input, model: SystemLanguageModel.default)
            case .privateCloudCompute:
                return try await analyze(input, model: PrivateCloudComputeLanguageModel())
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw Self.analysisError(from: error)
        }
    }

    private func analyze<Model: LanguageModel>(
        _ input: AssetModelAnalysisInput,
        model: Model
    ) async throws -> AssetAnalysisSuggestion {
        try Task.checkCancellation()
        let tools = Self.visionTools()
        let session = LanguageModelSession(
            model: model,
            tools: tools,
            instructions: """
            Extract only asset and purchase facts supported by the supplied image or text. \
            Never guess missing values. Keep metal karat separate from gemstone carat weight. \
            Use a catalog preset identifier only for an exact product match. Return nil for \
            every field that is absent or uncertain.
            """
        )
        let options = GenerationOptions(
            samplingMode: .greedy,
            temperature: nil,
            maximumResponseTokens: 1_200,
            toolCallingMode: tools.isEmpty ? .disallowed : .allowed
        )

        #if KARA_FOUNDATION_MODELS_TEXT_ONLY_COMPAT
        let response = try await session.respond(
            generating: GeneratedAssetAnalysis.self,
            options: options
        ) {
            Self.promptText(for: input)
        }
        #else
        let attachments = try Self.attachments(for: input)
        let response = try await session.respond(
            generating: GeneratedAssetAnalysis.self,
            options: options
        ) {
            Self.promptText(for: input)
            for attachment in attachments {
                attachment
            }
        }
        #endif

        try Task.checkCancellation()
        return Self.suggestion(from: response.content)
    }

    #if !KARA_FOUNDATION_MODELS_TEXT_ONLY_COMPAT
    private static func attachments(
        for input: AssetModelAnalysisInput
    ) throws -> [Attachment<ImageAttachmentContent>] {
        let imageData: [Data]
        let labels: [String]

        switch input.content {
        case let .objectPhoto(data):
            imageData = [data]
            labels = ["object-photo"]
        case let .invoice(invoice):
            imageData = invoice.renderedPageImages
            labels = invoice.selectedPageIndices.map { "invoice-page-\($0 + 1)" }
        }

        return try zip(imageData, labels).map { data, label in
            guard let image = UIImage(data: data), let cgImage = image.cgImage else {
                throw AssetAnalysisError.invalidInput
            }
            return Attachment(cgImage).label(label)
        }
    }
    #endif

    private static func visionTools() -> [any Tool] {
        #if targetEnvironment(simulator) || KARA_FOUNDATION_MODELS_TEXT_ONLY_COMPAT
        // The Xcode 27 beta simulator SDK doesn't ship the Vision/Foundation Models
        // cross-import overlay. The compatibility build also avoids vision symbols
        // that are absent from some iOS 27 beta runtimes.
        return []
        #else
        return [
            OCRTool(
                name: "extractDocumentText",
                description: "Extract exact text from a labeled object or invoice image."
            ),
        ]
        #endif
    }

    private static func promptText(for input: AssetModelAnalysisInput) -> String {
        let catalog = AssetCatalog.presets
            .map { preset in
                let metal = preset.metal?.rawValue ?? "unspecified"
                return "\(preset.id): \(preset.name) [\(preset.category.analysisIdentifier), \(metal)]"
            }
            .joined(separator: "\n")

        switch input.content {
        case .objectPhoto:
            return """
            Analyze the object photo and fill the structured fields. Read visible inscriptions \
            with the OCR tool when useful. Exact catalog choices are:\n\(catalog)
            """
        case let .invoice(invoice):
            return """
            Analyze these selected pages of one invoice and fill the structured purchase and \
            asset fields. Prefer exact values in the PDF text and OCR text below, and use the \
            labeled page images to resolve layout. Do not calculate or infer missing values.

            PDF text layer:
            \(invoice.extractedText)

            Vision OCR text:
            \(invoice.ocrText)

            Exact catalog choices:
            \(catalog)
            """
        }
    }

    static func suggestion(
        from generated: GeneratedAssetAnalysis
    ) -> AssetAnalysisSuggestion {
        let currencyCode = normalizedCurrencyCode(generated.currencyCode)
        let pricePaidMinorUnits = currencyCode.flatMap { code in
            generated.pricePaidAmount.flatMap {
                MoneyConverter.minorUnits(from: $0, currencyCode: code)
            }
        }

        return AssetAnalysisSuggestion(
            name: normalizedText(generated.name),
            category: generated.category.flatMap(AssetCategory.init(analysisIdentifier:)),
            presetID: generated.presetID.flatMap {
                AssetCatalog.preset(id: $0) == nil ? nil : $0
            },
            quantity: generated.quantity.flatMap { $0 > 0 ? $0 : nil },
            purchaseDate: parsedPurchaseDate(generated.purchaseDateISO8601),
            metal: generated.metal.flatMap(PreciousMetal.init(rawValue:)),
            weightGrams: validFinite(generated.weightGrams, range: 0...Double.greatestFiniteMagnitude),
            metalKarat: generated.metalKarat.flatMap { (1...24).contains($0) ? $0 : nil },
            finenessPermille: validFinite(generated.finenessPermille, range: 0...1_000),
            gemstoneCaratWeight: validFinite(
                generated.gemstoneCaratWeight,
                range: 0...Double.greatestFiniteMagnitude
            ),
            gemstoneClarity: normalizedText(generated.gemstoneClarity),
            pricePaidMinorUnits: pricePaidMinorUnits,
            currencyCode: currencyCode,
            sellerName: normalizedText(generated.sellerName),
            storageLocationName: normalizedText(generated.storageLocationName),
            invoiceNumber: normalizedText(generated.invoiceNumber)
        )
    }

    private static func normalizedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = AssetSuggestionNormalizer.displayName(value)
        return normalized.isEmpty ? nil : normalized
    }

    private static func normalizedCurrencyCode(_ value: String?) -> String? {
        guard let value else { return nil }
        let code = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased(with: Locale(identifier: "en_US_POSIX"))
        return SupportedAssetCurrency(rawValue: code)?.rawValue
    }

    private static func validFinite(
        _ value: Double?,
        range: ClosedRange<Double>
    ) -> Double? {
        guard let value, value.isFinite, range.contains(value), value > 0 else {
            return nil
        }
        return value
    }

    private static func parsedPurchaseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let parts = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4,
              parts[1].count == 2,
              parts[2].count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day
        )
        guard let date = calendar.date(from: components) else { return nil }
        let roundTrip = calendar.dateComponents([.year, .month, .day], from: date)
        guard roundTrip.year == year,
              roundTrip.month == month,
              roundTrip.day == day
        else {
            return nil
        }
        return date
    }

    private static func analysisError(from error: Error) -> AssetAnalysisError {
        if let error = error as? AssetAnalysisError {
            return error
        }
        if error is CancellationError {
            return .cancelled
        }
        if let error = error as? LanguageModelError {
            switch error {
            case .refusal, .guardrailViolation:
                return .refused
            case .unsupportedTranscriptContent:
                return .invalidInput
            case .unsupportedCapability, .unsupportedLanguageOrLocale:
                return .unavailable
            case .contextSizeExceeded, .rateLimited, .unsupportedGenerationGuide, .timeout:
                return .technicalFailure
            @unknown default:
                return .technicalFailure
            }
        }
        if error is SystemLanguageModel.Error {
            return .unavailable
        }
        if error is PrivateCloudComputeLanguageModel.Error {
            return .technicalFailure
        }
        if error is GeneratedContent.ParsingError {
            return .technicalFailure
        }
        return .technicalFailure
    }
}
