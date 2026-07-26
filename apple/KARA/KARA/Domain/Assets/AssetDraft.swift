import Foundation

nonisolated enum AssetAnalysisEvidenceKind: String, Equatable, Sendable {
    case visibleText = "visible_text"
    case visualIdentification = "visual_identification"
    case contextInference = "context_inference"
    case catalogDerived = "catalog_derived"
}

nonisolated enum AssetAnalysisMediaKind: Equatable, Sendable {
    case objectPhoto
    case invoice
}

nonisolated struct AssetFieldAssessment: Equatable, Sendable {
    let confidencePercent: Int
    let evidenceKind: AssetAnalysisEvidenceKind
    var mediaKind: AssetAnalysisMediaKind?

    init(
        confidencePercent: Int,
        evidenceKind: AssetAnalysisEvidenceKind,
        mediaKind: AssetAnalysisMediaKind? = nil
    ) {
        self.confidencePercent = min(max(confidencePercent, 1), 100)
        self.evidenceKind = evidenceKind
        self.mediaKind = mediaKind
    }
}

nonisolated struct AssetAnalysisSuggestion: Equatable, Sendable {
    var name: String?
    var category: AssetCategory?
    var presetID: String?
    var quantity: Int?
    var purchaseDate: Date?
    var metal: PreciousMetal?
    var weightGrams: Double?
    var metalKarat: Int?
    var finenessPermille: Double?
    var gemstoneCaratWeight: Double?
    var gemstoneClarity: String?
    var pricePaidMinorUnits: Int64?
    var currencyCode: String?
    var sellerName: String?
    var storageLocationName: String?
    var invoiceNumber: String?
    var serialNumber: String?
    var acquisitionMethod: AssetAcquisitionMethod?
    var fieldAssessments: [AssetDraft.Field: AssetFieldAssessment]

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
        evidenceKind: AssetAnalysisEvidenceKind = .visibleText,
        fieldAssessments: [AssetDraft.Field: AssetFieldAssessment] = [:]
    ) {
        self.name = name
        self.category = category
        self.presetID = presetID
        self.quantity = quantity
        self.purchaseDate = purchaseDate
        self.metal = metal
        self.weightGrams = weightGrams
        self.metalKarat = metalKarat
        self.finenessPermille = finenessPermille
        self.gemstoneCaratWeight = gemstoneCaratWeight
        self.gemstoneClarity = gemstoneClarity
        self.pricePaidMinorUnits = pricePaidMinorUnits
        self.currencyCode = currencyCode
        self.sellerName = sellerName
        self.storageLocationName = storageLocationName
        self.invoiceNumber = invoiceNumber
        self.serialNumber = serialNumber
        self.acquisitionMethod = acquisitionMethod
        let fallbackAssessment = AssetFieldAssessment(
            confidencePercent: confidencePercent,
            evidenceKind: evidenceKind
        )
        var assessments = fieldAssessments
        func register(_ field: AssetDraft.Field, when present: Bool) {
            if present, assessments[field] == nil {
                assessments[field] = fallbackAssessment
            }
        }
        register(.name, when: name != nil)
        register(.category, when: category != nil)
        register(.presetID, when: presetID != nil)
        register(.quantity, when: quantity != nil)
        register(.purchaseDate, when: purchaseDate != nil)
        register(.metal, when: metal != nil)
        register(.weightGrams, when: weightGrams != nil)
        register(.metalKarat, when: metalKarat != nil)
        register(.finenessPermille, when: finenessPermille != nil)
        register(.gemstoneCaratWeight, when: gemstoneCaratWeight != nil)
        register(.gemstoneClarity, when: gemstoneClarity != nil)
        register(.pricePaidMinorUnits, when: pricePaidMinorUnits != nil)
        register(.currencyCode, when: currencyCode != nil)
        register(.sellerName, when: sellerName != nil)
        register(.storageLocationName, when: storageLocationName != nil)
        register(.invoiceNumber, when: invoiceNumber != nil)
        register(.serialNumber, when: serialNumber != nil)
        register(.acquisitionMethod, when: acquisitionMethod != nil)
        self.fieldAssessments = assessments
    }

    func assessment(for field: AssetDraft.Field) -> AssetFieldAssessment? {
        fieldAssessments[field]
    }

    func stamped(with mediaKind: AssetAnalysisMediaKind) -> Self {
        var result = self
        result.fieldAssessments = result.fieldAssessments.mapValues { assessment in
            var stamped = assessment
            stamped.mediaKind = mediaKind
            return stamped
        }
        return result
    }

    func enrichedFromCatalog() -> Self {
        guard let presetID,
              let preset = AssetCatalog.preset(id: presetID),
              let presetAssessment = assessment(for: .presetID)
        else { return self }

        var result = self
        let derivedAssessment = AssetFieldAssessment(
            confidencePercent: presetAssessment.confidencePercent,
            evidenceKind: .catalogDerived,
            mediaKind: presetAssessment.mediaKind
        )
        func register(_ field: AssetDraft.Field) {
            result.fieldAssessments[field] = derivedAssessment
        }
        if result.name == nil {
            result.name = preset.name
            register(.name)
        }
        if result.category == nil {
            result.category = preset.category
            register(.category)
        }
        if result.metal == nil, let metal = preset.metal {
            result.metal = metal
            register(.metal)
        }
        if result.weightGrams == nil, let weight = preset.weightGrams {
            result.weightGrams = weight
            register(.weightGrams)
        }
        if result.metalKarat == nil, let karat = preset.metalKarat {
            result.metalKarat = karat
            register(.metalKarat)
        }
        if result.finenessPermille == nil, let fineness = preset.finenessPermille {
            result.finenessPermille = fineness
            register(.finenessPermille)
        }
        return result
    }
}

nonisolated enum AssetAnalysisSuggestionResolver {
    private struct Selection<Value> {
        let value: Value
        let assessment: AssetFieldAssessment
    }

    static func resolve(
        objectPhoto: AssetAnalysisSuggestion?,
        invoice: AssetAnalysisSuggestion?,
        preserving draft: AssetDraft? = nil
    ) -> AssetAnalysisSuggestion {
        let object = objectPhoto?
            .stamped(with: .objectPhoto)
            .enrichedFromCatalog()
        let invoice = invoice?
            .stamped(with: .invoice)
            .enrichedFromCatalog()
        var assessments: [AssetDraft.Field: AssetFieldAssessment] = [:]

        func selected<Value>(
            _ field: AssetDraft.Field,
            _ value: (AssetAnalysisSuggestion) -> Value?
        ) -> Value? {
            guard let choice = select(field, object: object, invoice: invoice, value: value) else {
                return nil
            }
            assessments[field] = choice.assessment
            return choice.value
        }

        let money = selectMoney(object: object, invoice: invoice)
        if let money {
            assessments[.pricePaidMinorUnits] = money.assessment
            assessments[.currencyCode] = money.assessment
        }
        var result = AssetAnalysisSuggestion(
            name: selected(.name, { $0.name }),
            category: selected(.category, { $0.category }),
            presetID: selected(.presetID, { $0.presetID }),
            quantity: selected(.quantity, { $0.quantity }),
            purchaseDate: selected(.purchaseDate, { $0.purchaseDate }),
            metal: selected(.metal, { $0.metal }),
            weightGrams: selected(.weightGrams, { $0.weightGrams }),
            metalKarat: selected(.metalKarat, { $0.metalKarat }),
            finenessPermille: selected(.finenessPermille, { $0.finenessPermille }),
            gemstoneCaratWeight: selected(.gemstoneCaratWeight, { $0.gemstoneCaratWeight }),
            gemstoneClarity: selected(.gemstoneClarity, { $0.gemstoneClarity }),
            pricePaidMinorUnits: money?.minorUnits,
            currencyCode: money?.currencyCode,
            sellerName: selected(.sellerName, { $0.sellerName }),
            storageLocationName: selected(.storageLocationName, { $0.storageLocationName }),
            invoiceNumber: selected(.invoiceNumber, { $0.invoiceNumber }),
            serialNumber: selected(.serialNumber, { $0.serialNumber }),
            acquisitionMethod: selected(.acquisitionMethod, { $0.acquisitionMethod }),
            fieldAssessments: assessments
        )
        if !presetIsConsistent(in: result) {
            result.presetID = nil
            result.fieldAssessments[.presetID] = nil
            removeCatalogDerivedFields(from: &result)
        }
        if let draft, !presetIsConsistent(withManualValuesIn: draft, suggestion: result) {
            result.presetID = nil
            result.fieldAssessments[.presetID] = nil
            removeCatalogDerivedFields(from: &result)
        }
        return result
    }

    private static func select<Value>(
        _ field: AssetDraft.Field,
        object: AssetAnalysisSuggestion?,
        invoice: AssetAnalysisSuggestion?,
        value: (AssetAnalysisSuggestion) -> Value?
    ) -> Selection<Value>? {
        let objectSelection = selection(field, suggestion: object, value: value)
        let invoiceSelection = selection(field, suggestion: invoice, value: value)
        switch (objectSelection, invoiceSelection) {
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

    private static func selection<Value>(
        _ field: AssetDraft.Field,
        suggestion: AssetAnalysisSuggestion?,
        value: (AssetAnalysisSuggestion) -> Value?
    ) -> Selection<Value>? {
        guard let suggestion,
              let value = value(suggestion),
              let assessment = suggestion.assessment(for: field)
        else { return nil }
        return Selection(value: value, assessment: assessment)
    }

    private struct MoneySelection {
        let minorUnits: Int64
        let currencyCode: String
        let assessment: AssetFieldAssessment
    }

    private static func selectMoney(
        object: AssetAnalysisSuggestion?,
        invoice: AssetAnalysisSuggestion?
    ) -> MoneySelection? {
        func money(from suggestion: AssetAnalysisSuggestion?) -> MoneySelection? {
            guard let suggestion,
                  let minorUnits = suggestion.pricePaidMinorUnits,
                  let currencyCode = suggestion.currencyCode,
                  let priceAssessment = suggestion.assessment(for: .pricePaidMinorUnits),
                  let currencyAssessment = suggestion.assessment(for: .currencyCode)
            else { return nil }
            let assessment = priceAssessment.confidencePercent <= currencyAssessment.confidencePercent
                ? priceAssessment
                : currencyAssessment
            return MoneySelection(
                minorUnits: minorUnits,
                currencyCode: currencyCode,
                assessment: assessment
            )
        }
        switch (money(from: object), money(from: invoice)) {
        case let (.some(object), .some(invoice)):
            return invoice.assessment.confidencePercent >= object.assessment.confidencePercent
                ? invoice
                : object
        case let (.some(object), .none): return object
        case let (.none, .some(invoice)): return invoice
        case (.none, .none): return nil
        }
    }

    private static func presetIsConsistent(in suggestion: AssetAnalysisSuggestion) -> Bool {
        guard let presetID = suggestion.presetID,
              let preset = AssetCatalog.preset(id: presetID)
        else { return suggestion.presetID == nil }
        if let category = suggestion.category, category != preset.category { return false }
        if let expectedMetal = preset.metal,
           let metal = suggestion.metal,
           metal != expectedMetal { return false }
        if !matches(suggestion.weightGrams, expected: preset.weightGrams) { return false }
        if !matches(
            suggestion.finenessPermille,
            expected: preset.finenessPermille,
            relativeTolerance: 0.002,
            absoluteTolerance: 1
        ) { return false }
        if let expectedKarat = preset.metalKarat,
           let karat = suggestion.metalKarat,
           karat != expectedKarat { return false }
        return true
    }

    private static func presetIsConsistent(
        withManualValuesIn draft: AssetDraft,
        suggestion: AssetAnalysisSuggestion
    ) -> Bool {
        guard let presetID = suggestion.presetID,
              let preset = AssetCatalog.preset(id: presetID)
        else { return suggestion.presetID == nil }
        let manual = draft.manuallyEditedFields
        if manual.contains(.category),
           let category = draft.category,
           category != preset.category { return false }
        if manual.contains(.metal),
           let expectedMetal = preset.metal,
           let metal = draft.metal,
           metal != expectedMetal { return false }
        if manual.contains(.weightGrams),
           !matches(draft.weightGrams, expected: preset.weightGrams) { return false }
        if manual.contains(.finenessPermille),
           !matches(
                draft.finenessPermille,
                expected: preset.finenessPermille,
                relativeTolerance: 0.002,
                absoluteTolerance: 1
           ) { return false }
        if manual.contains(.metalKarat),
           let expectedKarat = preset.metalKarat,
           let karat = draft.metalKarat,
           karat != expectedKarat { return false }
        return true
    }

    private static func matches(
        _ value: Double?,
        expected: Double?,
        relativeTolerance: Double = 0.01,
        absoluteTolerance: Double = 0.01
    ) -> Bool {
        guard let value, let expected else { return true }
        let tolerance = max(absoluteTolerance, abs(expected) * relativeTolerance)
        return abs(value - expected) <= tolerance
    }

    private static func removeCatalogDerivedFields(from suggestion: inout AssetAnalysisSuggestion) {
        let derivedFields = suggestion.fieldAssessments.compactMap { field, assessment in
            assessment.evidenceKind == .catalogDerived ? field : nil
        }
        for field in derivedFields {
            switch field {
            case .name: suggestion.name = nil
            case .category: suggestion.category = nil
            case .metal: suggestion.metal = nil
            case .weightGrams: suggestion.weightGrams = nil
            case .metalKarat: suggestion.metalKarat = nil
            case .finenessPermille: suggestion.finenessPermille = nil
            default: break
            }
            suggestion.fieldAssessments[field] = nil
        }
    }
}

nonisolated struct AssetAttachmentPayload: Equatable, Sendable {
    let kind: AssetAttachmentKind
    let filename: String
    let mimeType: String
    let pageCount: Int?
    let data: Data

    init(
        kind: AssetAttachmentKind,
        filename: String,
        mimeType: String,
        pageCount: Int? = nil,
        data: Data
    ) {
        self.kind = kind
        self.filename = filename
        self.mimeType = mimeType
        self.pageCount = pageCount
        self.data = data
    }
}

@MainActor
protocol AssetSaving {
    @discardableResult
    func save(draft: AssetDraft, attachments: [AssetAttachmentPayload]) throws -> Asset
}

@MainActor
protocol AssetUpdating {
    @discardableResult
    func update(assetID: UUID, with draft: AssetDraft) throws -> Asset
}

@MainActor
protocol AssetTrashManaging {
    func moveToTrash(assetID: UUID) throws
    func restore(assetID: UUID) throws
    func trashedAssets() throws -> [Asset]
    func purgeExpiredAssets(olderThan cutoff: Date) throws
    func permanentlyDelete(assetID: UUID) throws
}

@MainActor
protocol AttachmentManaging {
    func attachments(for assetID: UUID) throws -> [AssetAttachment]

    @discardableResult
    func add(_ payload: AssetAttachmentPayload, to assetID: UUID) throws -> AssetAttachment

    @discardableResult
    func rename(attachmentID: UUID, for assetID: UUID, to filename: String) throws -> AssetAttachment

    func delete(attachmentID: UUID, for assetID: UUID) throws
}

nonisolated enum AssetDraftValidationError: Error, Equatable, Sendable {
    case missingName
    case missingCategory
    case invalidQuantity
    case invalidWeight
    case invalidMetalKarat
    case invalidFineness
    case invalidGemstoneCaratWeight
    case invalidPrice
    case invalidCurrencyCode
}

nonisolated struct AssetDraft: Equatable, Sendable {
    enum Field: String, CaseIterable, Hashable, Sendable {
        case name
        case category
        case presetID
        case quantity
        case purchaseDate
        case metal
        case weightGrams
        case metalKarat
        case finenessPermille
        case gemstoneCaratWeight
        case gemstoneClarity
        case pricePaidMinorUnits
        case currencyCode
        case sellerName
        case storageLocationName
        case invoiceNumber
        case serialNumber
        case acquisitionMethod
        case tags
    }

    var name: String
    var category: AssetCategory?
    var presetID: String?
    var quantity: Int
    var purchaseDate: Date?
    var metal: PreciousMetal?
    var weightGrams: Double?
    var metalKarat: Int?
    var finenessPermille: Double?
    var gemstoneCaratWeight: Double?
    var gemstoneClarity: String
    var pricePaidMinorUnits: Int64?
    var currencyCode: String
    var sellerName: String
    var storageLocationName: String
    var invoiceNumber: String
    var serialNumber: String
    var acquisitionMethod: AssetAcquisitionMethod?
    var tags: [String]
    private(set) var manuallyEditedFields: Set<Field>

    init(
        name: String = "",
        category: AssetCategory? = nil,
        presetID: String? = nil,
        quantity: Int = 1,
        purchaseDate: Date? = nil,
        metal: PreciousMetal? = nil,
        weightGrams: Double? = nil,
        metalKarat: Int? = nil,
        finenessPermille: Double? = nil,
        gemstoneCaratWeight: Double? = nil,
        gemstoneClarity: String = "",
        pricePaidMinorUnits: Int64? = nil,
        currencyCode: String = SupportedAssetCurrency.defaultCurrency.rawValue,
        sellerName: String = "",
        storageLocationName: String = "",
        invoiceNumber: String = "",
        serialNumber: String = "",
        acquisitionMethod: AssetAcquisitionMethod? = nil,
        tags: [String] = [],
        manuallyEditedFields: Set<Field> = []
    ) {
        self.name = name
        self.category = category
        self.presetID = presetID
        self.quantity = quantity
        self.purchaseDate = purchaseDate
        self.metal = metal
        self.weightGrams = weightGrams
        self.metalKarat = metalKarat
        self.finenessPermille = finenessPermille
        self.gemstoneCaratWeight = gemstoneCaratWeight
        self.gemstoneClarity = gemstoneClarity
        self.pricePaidMinorUnits = pricePaidMinorUnits
        self.currencyCode = currencyCode
        self.sellerName = sellerName
        self.storageLocationName = storageLocationName
        self.invoiceNumber = invoiceNumber
        self.serialNumber = serialNumber
        self.acquisitionMethod = acquisitionMethod
        self.tags = tags
        self.manuallyEditedFields = manuallyEditedFields
    }

    @MainActor
    init(asset: Asset) {
        self.init(
            name: asset.name,
            category: asset.category,
            presetID: asset.presetID,
            quantity: asset.quantity,
            purchaseDate: asset.purchaseDate,
            metal: asset.metal,
            weightGrams: asset.weightGrams,
            metalKarat: asset.metalKarat,
            finenessPermille: asset.finenessPermille,
            gemstoneCaratWeight: asset.gemstoneCaratWeight,
            gemstoneClarity: asset.gemstoneClarity ?? "",
            pricePaidMinorUnits: asset.pricePaidMinorUnits,
            currencyCode: asset.currencyCode,
            sellerName: asset.sellerName ?? "",
            storageLocationName: asset.storageLocationName ?? "",
            invoiceNumber: asset.invoiceNumber ?? "",
            serialNumber: asset.serialNumber ?? "",
            acquisitionMethod: asset.acquisitionMethod,
            tags: asset.tags
        )
    }

    var validationErrors: [AssetDraftValidationError] {
        var errors: [AssetDraftValidationError] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.missingName)
        }
        if category == nil {
            errors.append(.missingCategory)
        }
        if quantity < 1 {
            errors.append(.invalidQuantity)
        }
        if let weightGrams, !weightGrams.isFinite || weightGrams <= 0 {
            errors.append(.invalidWeight)
        }
        if let metalKarat, !(1...24).contains(metalKarat) {
            errors.append(.invalidMetalKarat)
        }
        if let finenessPermille, !finenessPermille.isFinite || !(0...1_000).contains(finenessPermille) || finenessPermille == 0 {
            errors.append(.invalidFineness)
        }
        if let gemstoneCaratWeight, !gemstoneCaratWeight.isFinite || gemstoneCaratWeight <= 0 {
            errors.append(.invalidGemstoneCaratWeight)
        }
        if let pricePaidMinorUnits, pricePaidMinorUnits < 0 {
            errors.append(.invalidPrice)
        }
        if !SupportedAssetCurrency.isSupported(code: currencyCode) {
            errors.append(.invalidCurrencyCode)
        }
        return errors
    }

    var isValid: Bool { validationErrors.isEmpty }

    mutating func markAsManuallyEdited(_ field: Field) {
        manuallyEditedFields.insert(field)
    }

    mutating func apply(preset: AssetPreset) {
        presetID = preset.id
        category = preset.category
        name = preset.name
        metal = preset.metal
        weightGrams = preset.weightGrams
        metalKarat = preset.metalKarat
        finenessPermille = preset.finenessPermille
    }

    @discardableResult
    mutating func merge(
        suggestion: AssetAnalysisSuggestion,
        excluding excludedFields: Set<Field> = []
    ) -> Set<Field> {
        var appliedFields: Set<Field> = []

        if mergeString(\.name, field: .name, suggestion.name, excluding: excludedFields) {
            appliedFields.insert(.name)
        }
        if mergeOptional(\.category, field: .category, suggestion.category, excluding: excludedFields) {
            appliedFields.insert(.category)
        }
        if mergeOptional(\.presetID, field: .presetID, suggestion.presetID, excluding: excludedFields) {
            appliedFields.insert(.presetID)
        }
        if mergeQuantity(suggestion.quantity, excluding: excludedFields) {
            appliedFields.insert(.quantity)
        }
        if mergeOptional(\.purchaseDate, field: .purchaseDate, suggestion.purchaseDate, excluding: excludedFields) {
            appliedFields.insert(.purchaseDate)
        }
        if mergeOptional(\.metal, field: .metal, suggestion.metal, excluding: excludedFields) {
            appliedFields.insert(.metal)
        }
        if mergeOptional(
            \.weightGrams,
            field: .weightGrams,
            suggestion.weightGrams,
            excluding: excludedFields,
            isValid: { $0.isFinite && $0 > 0 }
        ) {
            appliedFields.insert(.weightGrams)
        }
        if mergeOptional(
            \.metalKarat,
            field: .metalKarat,
            suggestion.metalKarat,
            excluding: excludedFields,
            isValid: { (1...24).contains($0) }
        ) {
            appliedFields.insert(.metalKarat)
        }
        if mergeOptional(
            \.finenessPermille,
            field: .finenessPermille,
            suggestion.finenessPermille,
            excluding: excludedFields,
            isValid: { $0.isFinite && $0 > 0 && $0 <= 1_000 }
        ) {
            appliedFields.insert(.finenessPermille)
        }
        if mergeOptional(
            \.gemstoneCaratWeight,
            field: .gemstoneCaratWeight,
            suggestion.gemstoneCaratWeight,
            excluding: excludedFields,
            isValid: { $0.isFinite && $0 > 0 }
        ) {
            appliedFields.insert(.gemstoneCaratWeight)
        }
        if mergeString(
            \.gemstoneClarity,
            field: .gemstoneClarity,
            suggestion.gemstoneClarity,
            excluding: excludedFields
        ) {
            appliedFields.insert(.gemstoneClarity)
        }
        if mergeOptional(
            \.pricePaidMinorUnits,
            field: .pricePaidMinorUnits,
            suggestion.pricePaidMinorUnits,
            excluding: excludedFields,
            isValid: { $0 >= 0 }
        ) {
            appliedFields.insert(.pricePaidMinorUnits)
        }
        if mergeCurrencyCode(suggestion.currencyCode, excluding: excludedFields) {
            appliedFields.insert(.currencyCode)
        }
        if mergeString(\.sellerName, field: .sellerName, suggestion.sellerName, excluding: excludedFields) {
            appliedFields.insert(.sellerName)
        }
        if mergeString(
            \.storageLocationName,
            field: .storageLocationName,
            suggestion.storageLocationName,
            excluding: excludedFields
        ) {
            appliedFields.insert(.storageLocationName)
        }
        if mergeString(
            \.invoiceNumber,
            field: .invoiceNumber,
            suggestion.invoiceNumber,
            excluding: excludedFields
        ) {
            appliedFields.insert(.invoiceNumber)
        }
        if mergeString(
            \.serialNumber,
            field: .serialNumber,
            suggestion.serialNumber,
            excluding: excludedFields
        ) {
            appliedFields.insert(.serialNumber)
        }
        if mergeAcquisitionMethod(suggestion.acquisitionMethod, excluding: excludedFields) {
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
            case .tags: tags = []
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

    private mutating func mergeCurrencyCode(
        _ suggestion: String?,
        excluding excludedFields: Set<Field>
    ) -> Bool {
        guard !excludedFields.contains(.currencyCode),
              !manuallyEditedFields.contains(.currencyCode),
              currencyCode == SupportedAssetCurrency.defaultCurrency.rawValue,
              let suggestion,
              let currency = SupportedAssetCurrency.currency(normalizing: suggestion)
        else { return false }
        currencyCode = currency.rawValue
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

nonisolated enum AssetTagNormalizer {
    static func normalize(_ tags: [String]) -> [String] {
        var normalizedKeys: Set<String> = []
        return tags.compactMap { tag in
            let displayName = AssetSuggestionNormalizer.displayName(tag)
            guard !displayName.isEmpty else { return nil }
            let key = AssetSuggestionNormalizer.normalizedName(displayName)
            return normalizedKeys.insert(key).inserted ? displayName : nil
        }
    }
}

nonisolated enum AssetSuggestionNormalizer {
    static func displayName(_ value: String) -> String {
        value
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }

    static func normalizedName(_ value: String) -> String {
        displayName(value)
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            )
            .lowercased(with: Locale(identifier: "en_US_POSIX"))
    }
}

nonisolated enum MoneyConverter {
    private static let zeroDecimalCurrencies: Set<String> = [
        "BIF", "CLP", "DJF", "GNF", "JPY", "KMF", "KRW", "PYG", "RWF", "UGX", "VND", "VUV", "XAF", "XOF", "XPF",
    ]
    private static let threeDecimalCurrencies: Set<String> = [
        "BHD", "IQD", "JOD", "KWD", "LYD", "OMR", "TND",
    ]

    static func isSupportedCurrencyCode(_ currencyCode: String) -> Bool {
        let code = currencyCode.trimmingCharacters(in: .whitespacesAndNewlines)
        return code.count == 3
            && code == code.uppercased(with: Locale(identifier: "en_US_POSIX"))
            && Locale.Currency(code).isISOCurrency
    }

    static func minorUnitDigits(for currencyCode: String) -> Int? {
        guard isSupportedCurrencyCode(currencyCode) else { return nil }
        if zeroDecimalCurrencies.contains(currencyCode) { return 0 }
        if threeDecimalCurrencies.contains(currencyCode) { return 3 }
        return 2
    }

    static func minorUnits(from amount: Decimal, currencyCode: String) -> Int64? {
        guard amount >= 0, let digits = minorUnitDigits(for: currencyCode) else { return nil }
        var scaled = amount * powerOfTen(digits)
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        guard rounded <= Decimal(Int64.max) else { return nil }
        return NSDecimalNumber(decimal: rounded).int64Value
    }

    static func decimalAmount(from minorUnits: Int64, currencyCode: String) -> Decimal? {
        guard minorUnits >= 0, let digits = minorUnitDigits(for: currencyCode) else { return nil }
        return Decimal(minorUnits) / powerOfTen(digits)
    }

    private static func powerOfTen(_ exponent: Int) -> Decimal {
        (0..<exponent).reduce(Decimal(1)) { value, _ in value * 10 }
    }
}
