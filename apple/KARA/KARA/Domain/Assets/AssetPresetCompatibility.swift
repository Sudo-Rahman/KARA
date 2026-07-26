import Foundation

nonisolated enum AssetPresetCompatibility {
    static func matches(
        _ preset: AssetPreset,
        category: AssetCategory?,
        metal: PreciousMetal?,
        weightGrams: Double?,
        finenessPermille: Double?,
        metalKarat: Int?
    ) -> Bool {
        if let category, category != preset.category { return false }
        if let expectedMetal = preset.metal,
           let metal,
           metal != expectedMetal { return false }
        if !matchesNumber(weightGrams, expected: preset.weightGrams) { return false }
        if !matchesNumber(
            finenessPermille,
            expected: preset.finenessPermille,
            relativeTolerance: finenessRelativeTolerance,
            absoluteTolerance: finenessAbsoluteTolerance
        ) { return false }
        if let expectedKarat = preset.metalKarat,
           let metalKarat,
           metalKarat != expectedKarat { return false }
        return true
    }

    private static func matchesNumber(
        _ value: Double?,
        expected: Double?,
        relativeTolerance: Double = weightRelativeTolerance,
        absoluteTolerance: Double = weightAbsoluteTolerance
    ) -> Bool {
        guard let value, let expected else { return true }
        let tolerance = max(absoluteTolerance, abs(expected) * relativeTolerance)
        return abs(value - expected) <= tolerance
    }
}
