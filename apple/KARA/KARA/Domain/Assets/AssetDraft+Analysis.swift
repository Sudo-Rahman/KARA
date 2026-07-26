import Foundation

extension AssetDraft {
    @discardableResult
    mutating func merge(
        suggestion: AssetAnalysisSuggestion,
        excluding excludedFields: Set<Field> = []
    ) -> Set<Field> {
        var appliedFields: Set<Field> = []

        if mergeString(\.name, field: .name, suggestion.name?.value, excluding: excludedFields) {
            appliedFields.insert(.name)
        }
        if mergeOptional(\.category, field: .category, suggestion.category?.value, excluding: excludedFields) {
            appliedFields.insert(.category)
        }
        if mergeOptional(\.presetID, field: .presetID, suggestion.presetID?.value, excluding: excludedFields) {
            appliedFields.insert(.presetID)
        }
        if mergeQuantity(suggestion.quantity?.value, excluding: excludedFields) {
            appliedFields.insert(.quantity)
        }
        if mergeOptional(\.purchaseDate, field: .purchaseDate, suggestion.purchaseDate?.value, excluding: excludedFields) {
            appliedFields.insert(.purchaseDate)
        }
        if mergeOptional(\.metal, field: .metal, suggestion.metal?.value, excluding: excludedFields) {
            appliedFields.insert(.metal)
        }
        if mergeOptional(
            \.weightGrams,
            field: .weightGrams,
            suggestion.weightGrams?.value,
            excluding: excludedFields,
            isValid: { $0.isFinite && $0 > 0 }
        ) {
            appliedFields.insert(.weightGrams)
        }
        if mergeOptional(
            \.metalKarat,
            field: .metalKarat,
            suggestion.metalKarat?.value,
            excluding: excludedFields,
            isValid: { (1...24).contains($0) }
        ) {
            appliedFields.insert(.metalKarat)
        }
        if mergeOptional(
            \.finenessPermille,
            field: .finenessPermille,
            suggestion.finenessPermille?.value,
            excluding: excludedFields,
            isValid: { $0.isFinite && $0 > 0 && $0 <= 1_000 }
        ) {
            appliedFields.insert(.finenessPermille)
        }
        if mergeOptional(
            \.gemstoneCaratWeight,
            field: .gemstoneCaratWeight,
            suggestion.gemstoneCaratWeight?.value,
            excluding: excludedFields,
            isValid: { $0.isFinite && $0 > 0 }
        ) {
            appliedFields.insert(.gemstoneCaratWeight)
        }
        if mergeString(
            \.gemstoneClarity,
            field: .gemstoneClarity,
            suggestion.gemstoneClarity?.value,
            excluding: excludedFields
        ) {
            appliedFields.insert(.gemstoneClarity)
        }
        if mergePrice(suggestion.pricePaid?.value, excluding: excludedFields) {
            appliedFields.formUnion([.pricePaidMinorUnits, .currencyCode])
        }
        if mergeString(\.sellerName, field: .sellerName, suggestion.sellerName?.value, excluding: excludedFields) {
            appliedFields.insert(.sellerName)
        }
        if mergeString(
            \.storageLocationName,
            field: .storageLocationName,
            suggestion.storageLocationName?.value,
            excluding: excludedFields
        ) {
            appliedFields.insert(.storageLocationName)
        }
        if mergeString(
            \.invoiceNumber,
            field: .invoiceNumber,
            suggestion.invoiceNumber?.value,
            excluding: excludedFields
        ) {
            appliedFields.insert(.invoiceNumber)
        }
        if mergeString(
            \.serialNumber,
            field: .serialNumber,
            suggestion.serialNumber?.value,
            excluding: excludedFields
        ) {
            appliedFields.insert(.serialNumber)
        }
        if mergeAcquisitionMethod(suggestion.acquisitionMethod?.value, excluding: excludedFields) {
            appliedFields.insert(.acquisitionMethod)
        }
        return appliedFields
    }

    mutating func clearSuggestedFields(_ fields: Set<Field>) {
        for field in fields where !manuallyEditedFields.contains(field) {
            switch field {
            case .name: name = ""
            case .category: category = nil
            case .presetID: presetID = nil
            case .quantity: quantity = 1
            case .purchaseDate: purchaseDate = nil
            case .metal: metal = nil
            case .weightGrams: weightGrams = nil
            case .metalKarat: metalKarat = nil
            case .finenessPermille: finenessPermille = nil
            case .gemstoneCaratWeight: gemstoneCaratWeight = nil
            case .gemstoneClarity: gemstoneClarity = ""
            case .pricePaidMinorUnits: pricePaidMinorUnits = nil
            case .currencyCode: currencyCode = SupportedAssetCurrency.defaultCurrency.rawValue
            case .sellerName: sellerName = ""
            case .storageLocationName: storageLocationName = ""
            case .invoiceNumber: invoiceNumber = ""
            case .serialNumber: serialNumber = ""
            case .acquisitionMethod: acquisitionMethod = .purchase
            case .tags: break
            }
        }
    }

    private mutating func mergeString(
        _ keyPath: WritableKeyPath<Self, String>,
        field: Field,
        _ suggestion: String?,
        excluding excludedFields: Set<Field>,
        isValid: (String) -> Bool = { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    ) -> Bool {
        guard !excludedFields.contains(field),
              !manuallyEditedFields.contains(field),
              self[keyPath: keyPath].trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let suggestion,
              isValid(suggestion)
        else { return false }
        self[keyPath: keyPath] = suggestion.trimmingCharacters(in: .whitespacesAndNewlines)
        return true
    }

    private mutating func mergeOptional<Value>(
        _ keyPath: WritableKeyPath<Self, Value?>,
        field: Field,
        _ suggestion: Value?,
        excluding excludedFields: Set<Field>,
        isValid: (Value) -> Bool = { _ in true }
    ) -> Bool {
        guard !excludedFields.contains(field),
              !manuallyEditedFields.contains(field),
              self[keyPath: keyPath] == nil,
              let suggestion,
              isValid(suggestion)
        else { return false }
        self[keyPath: keyPath] = suggestion
        return true
    }

    private mutating func mergeQuantity(
        _ suggestion: Int?,
        excluding excludedFields: Set<Field>
    ) -> Bool {
        guard !excludedFields.contains(.quantity),
              !manuallyEditedFields.contains(.quantity),
              quantity == 1,
              let suggestion,
              suggestion > 0
        else { return false }
        quantity = suggestion
        return true
    }

    private mutating func mergePrice(
        _ suggestion: AssetAnalysisPrice?,
        excluding excludedFields: Set<Field>
    ) -> Bool {
        let fields: Set<Field> = [.pricePaidMinorUnits, .currencyCode]
        guard excludedFields.isDisjoint(with: fields),
              manuallyEditedFields.isDisjoint(with: fields),
              pricePaidMinorUnits == nil,
              currencyCode == SupportedAssetCurrency.defaultCurrency.rawValue,
              let suggestion,
              suggestion.minorUnits >= 0
        else { return false }
        pricePaidMinorUnits = suggestion.minorUnits
        currencyCode = suggestion.currency.rawValue
        return true
    }

    private mutating func mergeAcquisitionMethod(
        _ suggestion: AssetAcquisitionMethod?,
        excluding excludedFields: Set<Field>
    ) -> Bool {
        guard !excludedFields.contains(.acquisitionMethod),
              !manuallyEditedFields.contains(.acquisitionMethod),
              acquisitionMethod == nil || acquisitionMethod == .purchase,
              let suggestion
        else { return false }
        acquisitionMethod = suggestion
        return true
    }
}
