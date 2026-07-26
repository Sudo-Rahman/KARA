import Foundation

nonisolated enum AssetAnalysisEvidenceKind: String, Equatable, Sendable {
    case visibleText = "visible_text"
    case visualIdentification = "visual_identification"
    case contextInference = "context_inference"
    case catalogDerived = "catalog_derived"
}

nonisolated struct AssetFieldAssessment: Equatable, Sendable {
    let confidencePercent: Int
    let evidenceKind: AssetAnalysisEvidenceKind

    init(confidencePercent: Int, evidenceKind: AssetAnalysisEvidenceKind) {
        self.confidencePercent = min(max(confidencePercent, 1), 100)
        self.evidenceKind = evidenceKind
    }
}

nonisolated struct AssetAnalysisCandidate<Value: Equatable & Sendable>: Equatable, Sendable {
    let value: Value
    let assessment: AssetFieldAssessment
}

nonisolated struct AssetAnalysisPrice: Equatable, Sendable {
    let minorUnits: Int64
    let currency: SupportedAssetCurrency
}

nonisolated struct AssetAnalysisSuggestion: Equatable, Sendable {
    var name: AssetAnalysisCandidate<String>?
    var category: AssetAnalysisCandidate<AssetCategory>?
    var presetID: AssetAnalysisCandidate<String>?
    var quantity: AssetAnalysisCandidate<Int>?
    var purchaseDate: AssetAnalysisCandidate<Date>?
    var metal: AssetAnalysisCandidate<PreciousMetal>?
    var weightGrams: AssetAnalysisCandidate<Double>?
    var metalKarat: AssetAnalysisCandidate<Int>?
    var finenessPermille: AssetAnalysisCandidate<Double>?
    var gemstoneCaratWeight: AssetAnalysisCandidate<Double>?
    var gemstoneClarity: AssetAnalysisCandidate<String>?
    var pricePaid: AssetAnalysisCandidate<AssetAnalysisPrice>?
    var sellerName: AssetAnalysisCandidate<String>?
    var storageLocationName: AssetAnalysisCandidate<String>?
    var invoiceNumber: AssetAnalysisCandidate<String>?
    var serialNumber: AssetAnalysisCandidate<String>?
    var acquisitionMethod: AssetAnalysisCandidate<AssetAcquisitionMethod>?

    init(
        name: String? = nil,
        category: AssetCategory? = nil,
        presetID: String? = nil,
        quantity: Int? = nil,
        purchaseDate: Date? = nil,
        metal: PreciousMetal? = nil,
        weightGrams: Double? = nil,
        metalKarat: Int? = nil,
        finenessPermille: Double? = nil,
        gemstoneCaratWeight: Double? = nil,
        gemstoneClarity: String? = nil,
        pricePaidMinorUnits: Int64? = nil,
        currencyCode: String? = nil,
        sellerName: String? = nil,
        storageLocationName: String? = nil,
        invoiceNumber: String? = nil,
        serialNumber: String? = nil,
        acquisitionMethod: AssetAcquisitionMethod? = nil,
        confidencePercent: Int = 100,
        evidenceKind: AssetAnalysisEvidenceKind = .visibleText
    ) {
        let assessment = AssetFieldAssessment(
            confidencePercent: confidencePercent,
            evidenceKind: evidenceKind
        )
        func candidate<Value: Equatable & Sendable>(
            _ value: Value?
        ) -> AssetAnalysisCandidate<Value>? {
            value.map { AssetAnalysisCandidate(value: $0, assessment: assessment) }
        }

        self.name = candidate(name)
        self.category = candidate(category)
        self.presetID = candidate(presetID)
        self.quantity = candidate(quantity)
        self.purchaseDate = candidate(purchaseDate)
        self.metal = candidate(metal)
        self.weightGrams = candidate(weightGrams)
        self.metalKarat = candidate(metalKarat)
        self.finenessPermille = candidate(finenessPermille)
        self.gemstoneCaratWeight = candidate(gemstoneCaratWeight)
        self.gemstoneClarity = candidate(gemstoneClarity)
        if let pricePaidMinorUnits,
           let currencyCode,
           let currency = SupportedAssetCurrency.currency(normalizing: currencyCode) {
            pricePaid = AssetAnalysisCandidate(
                value: AssetAnalysisPrice(
                    minorUnits: pricePaidMinorUnits,
                    currency: currency
                ),
                assessment: assessment
            )
        } else {
            pricePaid = nil
        }
        self.sellerName = candidate(sellerName)
        self.storageLocationName = candidate(storageLocationName)
        self.invoiceNumber = candidate(invoiceNumber)
        self.serialNumber = candidate(serialNumber)
        self.acquisitionMethod = candidate(acquisitionMethod)
    }

    func enrichedFromCatalog() -> Self {
        guard let presetCandidate = presetID,
              let preset = AssetCatalog.preset(id: presetCandidate.value)
        else {
            return self
        }

        var result = self
        let assessment = AssetFieldAssessment(
            confidencePercent: presetCandidate.assessment.confidencePercent,
            evidenceKind: .catalogDerived
        )
        if result.name == nil {
            result.name = AssetAnalysisCandidate(value: preset.name, assessment: assessment)
        }
        if result.category == nil {
            result.category = AssetAnalysisCandidate(value: preset.category, assessment: assessment)
        }
        if result.metal == nil, let metal = preset.metal {
            result.metal = AssetAnalysisCandidate(value: metal, assessment: assessment)
        }
        if result.weightGrams == nil, let weight = preset.weightGrams {
            result.weightGrams = AssetAnalysisCandidate(value: weight, assessment: assessment)
        }
        if result.metalKarat == nil, let karat = preset.metalKarat {
            result.metalKarat = AssetAnalysisCandidate(value: karat, assessment: assessment)
        }
        if result.finenessPermille == nil, let fineness = preset.finenessPermille {
            result.finenessPermille = AssetAnalysisCandidate(value: fineness, assessment: assessment)
        }
        return result
    }
}

nonisolated enum AssetAnalysisSuggestionResolver {
    static func resolve(
        objectPhoto: AssetAnalysisSuggestion?,
        invoice: AssetAnalysisSuggestion?,
        preserving draft: AssetDraft? = nil
    ) -> AssetAnalysisSuggestion {
        let object = objectPhoto?.enrichedFromCatalog()
        let invoice = invoice?.enrichedFromCatalog()
        var result = AssetAnalysisSuggestion()
        result.name = select(\.name, object: object, invoice: invoice)
        result.category = select(\.category, object: object, invoice: invoice)
        result.presetID = select(\.presetID, object: object, invoice: invoice)
        result.quantity = select(\.quantity, object: object, invoice: invoice)
        result.purchaseDate = select(\.purchaseDate, object: object, invoice: invoice)
        result.metal = select(\.metal, object: object, invoice: invoice)
        result.weightGrams = select(\.weightGrams, object: object, invoice: invoice)
        result.metalKarat = select(\.metalKarat, object: object, invoice: invoice)
        result.finenessPermille = select(\.finenessPermille, object: object, invoice: invoice)
        result.gemstoneCaratWeight = select(\.gemstoneCaratWeight, object: object, invoice: invoice)
        result.gemstoneClarity = select(\.gemstoneClarity, object: object, invoice: invoice)
        result.pricePaid = select(\.pricePaid, object: object, invoice: invoice)
        result.sellerName = select(\.sellerName, object: object, invoice: invoice)
        result.storageLocationName = select(\.storageLocationName, object: object, invoice: invoice)
        result.invoiceNumber = select(\.invoiceNumber, object: object, invoice: invoice)
        result.serialNumber = select(\.serialNumber, object: object, invoice: invoice)
        result.acquisitionMethod = select(\.acquisitionMethod, object: object, invoice: invoice)

        if !presetIsConsistent(in: result)
            || draft.map({ !presetIsConsistent(withManualValuesIn: $0, suggestion: result) }) == true
        {
            result.presetID = nil
            removeCatalogDerivedFields(from: &result)
        }
        return result
    }

    private static func select<Value: Equatable & Sendable>(
        _ keyPath: KeyPath<AssetAnalysisSuggestion, AssetAnalysisCandidate<Value>?>,
        object: AssetAnalysisSuggestion?,
        invoice: AssetAnalysisSuggestion?
    ) -> AssetAnalysisCandidate<Value>? {
        let objectCandidate = object?[keyPath: keyPath]
        let invoiceCandidate = invoice?[keyPath: keyPath]
        switch (objectCandidate, invoiceCandidate) {
        case let (.some(object), .some(invoice)):
            return invoice.assessment.confidencePercent >= object.assessment.confidencePercent
                ? invoice
                : object
        case let (.some(object), .none):
            return object
        case let (.none, .some(invoice)):
            return invoice
        case (.none, .none):
            return nil
        }
    }

    private static func presetIsConsistent(in suggestion: AssetAnalysisSuggestion) -> Bool {
        guard let presetID = suggestion.presetID?.value,
              let preset = AssetCatalog.preset(id: presetID)
        else {
            return suggestion.presetID == nil
        }
        return AssetPresetCompatibility.matches(
            preset,
            category: suggestion.category?.value,
            metal: suggestion.metal?.value,
            weightGrams: suggestion.weightGrams?.value,
            finenessPermille: suggestion.finenessPermille?.value,
            metalKarat: suggestion.metalKarat?.value
        )
    }

    private static func presetIsConsistent(
        withManualValuesIn draft: AssetDraft,
        suggestion: AssetAnalysisSuggestion
    ) -> Bool {
        guard let presetID = suggestion.presetID?.value,
              let preset = AssetCatalog.preset(id: presetID)
        else {
            return suggestion.presetID == nil
        }
        let manual = draft.manuallyEditedFields
        return AssetPresetCompatibility.matches(
            preset,
            category: manual.contains(.category) ? draft.category : nil,
            metal: manual.contains(.metal) ? draft.metal : nil,
            weightGrams: manual.contains(.weightGrams) ? draft.weightGrams : nil,
            finenessPermille: manual.contains(.finenessPermille) ? draft.finenessPermille : nil,
            metalKarat: manual.contains(.metalKarat) ? draft.metalKarat : nil
        )
    }

    private static func removeCatalogDerivedFields(from suggestion: inout AssetAnalysisSuggestion) {
        clearCatalogDerived(\.name, from: &suggestion)
        clearCatalogDerived(\.category, from: &suggestion)
        clearCatalogDerived(\.metal, from: &suggestion)
        clearCatalogDerived(\.weightGrams, from: &suggestion)
        clearCatalogDerived(\.metalKarat, from: &suggestion)
        clearCatalogDerived(\.finenessPermille, from: &suggestion)
    }

    private static func clearCatalogDerived<Value: Equatable & Sendable>(
        _ keyPath: WritableKeyPath<AssetAnalysisSuggestion, AssetAnalysisCandidate<Value>?>,
        from suggestion: inout AssetAnalysisSuggestion
    ) {
        guard suggestion[keyPath: keyPath]?.assessment.evidenceKind == .catalogDerived else {
            return
        }
        suggestion[keyPath: keyPath] = nil
    }
}
