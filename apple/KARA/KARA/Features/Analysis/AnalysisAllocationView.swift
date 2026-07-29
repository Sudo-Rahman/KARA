import Charts
import SwiftUI

@MainActor
enum AnalysisAllocationPalette {
    static func color(for index: Int, theme: KaraTheme) -> Color {
        switch index % 6 {
        case 0:
            theme.goldBright
        case 1:
            theme.cobaltBright
        case 2:
            .cyan
        case 3:
            .mint
        case 4:
            .orange
        default:
            .purple
        }
    }
}

struct AnalysisAllocationView: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let snapshot: PortfolioAnalyticsSnapshot

    @State private var selectedKind: AnalysisBreakdownKind = .categories
    @State private var selectedAngle: Double?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: KaraSpacing.large) {
                Text(AnalysisCopy.resource("analysis.allocation.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                kindPicker

                if selectedBreakdown.items.isEmpty {
                    unavailableCard
                } else {
                    allocationCard
                    portfolioReadingCard
                }

                exposureOverviewCard
            }
            .padding(.horizontal, KaraSpacing.medium)
            .padding(.top, KaraSpacing.small)
            .padding(.bottom, KaraSpacing.xxLarge)
        }
        .scrollIndicators(.hidden)
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(AnalysisCopy.resource("analysis.allocation.title"))
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("analysis.allocation")
        .onChange(of: selectedKind) {
            selectedAngle = nil
        }
    }

    private var kindPicker: some View {
        Picker(
            AnalysisCopy.resource("analysis.allocation.picker"),
            selection: $selectedKind
        ) {
            ForEach(AnalysisBreakdownKind.allCases) { kind in
                Text(kind.label)
                    .tag(kind)
            }
        }
        .pickerStyle(.segmented)
        .frame(minHeight: 44)
        .tint(theme.goldBright)
        .accessibilityIdentifier("analysis.allocation.picker")
    }

    private var allocationCard: some View {
        KaraCard(padding: KaraSpacing.large) {
            VStack(alignment: .leading, spacing: KaraSpacing.large) {
                VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                    HStack(spacing: KaraSpacing.small) {
                        Image(systemName: selectedKind.systemImage)
                            .foregroundStyle(theme.goldBright)
                            .accessibilityHidden(true)

                        Text(selectedKind.label)
                            .font(.headline)
                            .foregroundStyle(theme.ink)
                    }

                    AnalysisCopy.text("analysis.allocation.chart.detail")
                        .font(.caption)
                        .foregroundStyle(theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: KaraSpacing.large) {
                        allocationChart
                            .frame(maxWidth: .infinity)
                        allocationLegend
                    }
                } else {
                    HStack(alignment: .center, spacing: KaraSpacing.small) {
                        allocationChart
                        allocationLegend
                    }
                }

                if !selectedBreakdown.coverage.isComplete {
                    Label(
                        AnalysisCopy.resource("analysis.allocation.partial"),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(theme.goldBright)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .id("analysis.allocation.chart")
        .accessibilityIdentifier("analysis.allocation.chart-card")
    }

    private var allocationChart: some View {
        ZStack {
            SensitiveValue {
                Chart {
                    ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                        SectorMark(
                            angle: .value(
                                segment.localizedName(kind: selectedKind),
                                segment.valueEUR.vaultDouble
                            ),
                            innerRadius: .ratio(0.70),
                            angularInset: 1.8
                        )
                        .cornerRadius(3)
                        .foregroundStyle(
                            segment.isUnassigned
                                ? theme.muted.opacity(0.46)
                                : AnalysisAllocationPalette.color(
                                    for: index,
                                    theme: theme
                                )
                        )
                        .opacity(
                            selectedSegment == nil || selectedSegment?.id == segment.id
                                ? 1
                                : 0.34
                        )
                    }
                }
                .chartLegend(.hidden)
                .chartAngleSelection(value: $selectedAngle)
            }

            chartCenter
                .allowsHitTesting(false)
        }
        .frame(width: 140, height: 176)
        .animation(
            KaraMotion.controlResponse(reduceMotion: reduceMotion),
            value: selectedSegment?.id
        )
    }

    private var chartCenter: some View {
        VStack(spacing: KaraSpacing.xSmall) {
            SensitiveValue {
                Text(VaultFormatters.currency(
                    selectedSegment?.valueEUR
                        ?? selectedBreakdown.coverage.totalKnownValueEUR
                ))
                .font(theme.displayFont(size: 19, relativeTo: .title3))
                .monospacedDigit()
                .foregroundStyle(theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
            }

            if let selectedSegment {
                if selectedSegment.isUnassigned {
                    AnalysisCopy.text("analysis.allocation.unassigned")
                        .font(.caption2)
                        .foregroundStyle(theme.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                } else if let key = selectedSegment.key {
                    AnalysisBreakdownLabel(key: key, kind: selectedKind)
                        .font(.caption2)
                        .foregroundStyle(theme.muted)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            } else {
                AnalysisCopy.text("analysis.allocation.total-value")
                    .font(.caption2)
                    .foregroundStyle(theme.muted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, KaraSpacing.medium)
        .frame(width: 98)
    }

    private var allocationLegend: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
            ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                Button {
                    toggleSelection(of: segment)
                } label: {
                    legendRow(segment, index: index)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendRow(
        _ segment: AnalysisAllocationSegment,
        index: Int
    ) -> some View {
        HStack(spacing: KaraSpacing.small) {
            Circle()
                .fill(
                    segment.isUnassigned
                        ? theme.muted.opacity(0.46)
                        : AnalysisAllocationPalette.color(for: index, theme: theme)
                )
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                if segment.isUnassigned {
                    AnalysisCopy.text("analysis.allocation.unassigned")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                } else if let key = segment.key {
                    AnalysisBreakdownLabel(key: key, kind: selectedKind)
                        .font(
                            selectedKind == .locations
                                ? .caption.weight(.semibold)
                                : .subheadline.weight(.medium)
                        )
                        .foregroundStyle(theme.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let recordCount = segment.recordCount {
                    Text(AnalysisCopy.formatted(
                        String.LocalizationValue(
                            AnalysisAllocationCountCopy
                                .recordLocalizationKey(for: recordCount)
                        ),
                        recordCount
                    ))
                    .font(.caption2)
                    .foregroundStyle(theme.muted)
                }
            }

            Spacer(minLength: KaraSpacing.xSmall)

            VStack(alignment: .trailing, spacing: 2) {
                SensitiveValue {
                    Text(VaultFormatters.currency(segment.valueEUR))
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                if let share = segment.sharePercentage {
                    SensitiveValue {
                        Text(VaultFormatters.percentage(
                            share,
                            maximumFractionDigits: 1
                        ))
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(theme.goldBright)
                    }
                }
            }
        }
        .padding(.horizontal, KaraSpacing.small)
        .frame(minHeight: 44)
        .background(
            selectedSegment?.id == segment.id
                ? theme.cobalt.opacity(0.16)
                : .clear,
            in: .rect(cornerRadius: 12)
        )
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var portfolioReadingCard: some View {
        KaraCard(padding: KaraSpacing.large) {
            VStack(alignment: .leading, spacing: KaraSpacing.large) {
                sectionHeader(
                    title: "analysis.allocation.reading.title",
                    detail: "analysis.allocation.reading.detail"
                )

                HStack(alignment: .top, spacing: KaraSpacing.medium) {
                    Image(systemName: concentrationSystemImage)
                        .font(.headline)
                        .foregroundStyle(concentrationTint)
                        .frame(width: 40, height: 40)
                        .background(concentrationTint.opacity(0.12), in: .circle)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                        AnalysisCopy.text(concentrationTitle)
                            .font(.headline)
                            .foregroundStyle(theme.ink)

                        SensitiveValue {
                            Text(verbatim: concentrationDetail)
                                .font(.caption)
                                .foregroundStyle(theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                GeometryReader { geometry in
                    Capsule()
                        .fill(theme.muted.opacity(0.14))
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(concentrationTint)
                                .frame(
                                    width: geometry.size.width * concentrationRatio
                                )
                        }
                }
                .frame(height: 8)
                .accessibilityHidden(true)

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                        allocationMetric(
                            title: "analysis.allocation.metric.groups",
                            value: String(selectedBreakdown.items.count)
                        )
                        allocationMetric(
                            title: "analysis.allocation.metric.assets",
                            value: coverageCount
                        )
                        allocationMetric(
                            title: "analysis.allocation.metric.coverage",
                            value: coveragePercentage
                        )
                    }
                } else {
                    HStack(alignment: .top, spacing: KaraSpacing.medium) {
                        allocationMetric(
                            title: "analysis.allocation.metric.groups",
                            value: String(selectedBreakdown.items.count)
                        )
                        allocationMetric(
                            title: "analysis.allocation.metric.assets",
                            value: coverageCount
                        )
                        allocationMetric(
                            title: "analysis.allocation.metric.coverage",
                            value: coveragePercentage
                        )
                    }
                }
            }
        }
        .accessibilityIdentifier("analysis.allocation.reading")
    }

    private var exposureOverviewCard: some View {
        KaraCard(padding: KaraSpacing.large) {
            VStack(alignment: .leading, spacing: KaraSpacing.large) {
                sectionHeader(
                    title: "analysis.allocation.exposures.title",
                    detail: "analysis.allocation.exposures.detail"
                )

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(AnalysisBreakdownKind.allCases.enumerated()), id: \.element.id) {
                        index,
                        kind in
                        if index > 0 {
                            Divider()
                                .overlay(theme.muted.opacity(0.16))
                        }

                        leadingExposureRow(for: kind)
                            .padding(.vertical, KaraSpacing.small)
                    }
                }
            }
        }
        .accessibilityIdentifier("analysis.allocation.exposures")
    }

    private func leadingExposureRow(
        for kind: AnalysisBreakdownKind
    ) -> some View {
        let breakdown = breakdown(for: kind)

        return HStack(spacing: KaraSpacing.medium) {
            Image(systemName: kind.systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.cobaltBright)
                .frame(width: 38, height: 38)
                .background(theme.cobalt.opacity(0.13), in: .circle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                Text(kind.label)
                    .font(.caption)
                    .foregroundStyle(theme.muted)

                if let leading = breakdown.items.first {
                    AnalysisBreakdownLabel(key: leading.key, kind: kind)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                } else {
                    AnalysisCopy.text("analysis.allocation.missing")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.muted)
                }
            }

            Spacer(minLength: KaraSpacing.small)

            if let share = breakdown.items.first?.sharePercentage {
                SensitiveValue {
                    Text(VaultFormatters.percentage(
                        share,
                        maximumFractionDigits: 0
                    ))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(theme.goldBright)
                }
            } else {
                Text("—")
                    .font(.headline)
                    .foregroundStyle(theme.muted)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var unavailableCard: some View {
        KaraCard(padding: KaraSpacing.large) {
            VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                Image(systemName: selectedKind.systemImage)
                    .font(.title2)
                    .foregroundStyle(theme.goldBright)
                    .accessibilityHidden(true)

                AnalysisCopy.text("analysis.allocation.unavailable")
                    .font(.subheadline)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .leading)
        }
    }

    private func sectionHeader(
        title: String.LocalizationValue,
        detail: String.LocalizationValue
    ) -> some View {
        VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
            AnalysisCopy.text(title)
                .font(theme.displayFont(size: 21, relativeTo: .title3))
                .foregroundStyle(theme.ink)

            AnalysisCopy.text(detail)
                .font(.caption)
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func allocationMetric(
        title: String.LocalizationValue,
        value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
            AnalysisCopy.text(title)
                .font(.caption2)
                .foregroundStyle(theme.muted)

            SensitiveValue {
                Text(verbatim: value)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectedBreakdown: PortfolioAnalyticsBreakdown {
        breakdown(for: selectedKind)
    }

    private func breakdown(
        for kind: AnalysisBreakdownKind
    ) -> PortfolioAnalyticsBreakdown {
        switch kind {
        case .categories:
            snapshot.categories
        case .locations:
            snapshot.storageLocations
        case .metals:
            snapshot.metals
        }
    }

    private var segments: [AnalysisAllocationSegment] {
        var values = selectedBreakdown.items.map {
            AnalysisAllocationSegment(
                id: "known:\($0.key)",
                key: $0.key,
                valueEUR: $0.valueEUR,
                sharePercentage: $0.sharePercentage,
                recordCount: $0.recordCount,
                isUnassigned: false
            )
        }
        let missingValue = max(
            0,
            selectedBreakdown.coverage.totalKnownValueEUR
                - selectedBreakdown.coverage.representedValueEUR
        )
        if missingValue > 0 {
            let total = selectedBreakdown.coverage.totalKnownValueEUR
            values.append(AnalysisAllocationSegment(
                id: "unassigned",
                key: nil,
                valueEUR: missingValue,
                sharePercentage: total > 0 ? missingValue / total * 100 : nil,
                recordCount: nil,
                isUnassigned: true
            ))
        }
        return values
    }

    private var selectedSegment: AnalysisAllocationSegment? {
        guard let selectedAngle else { return nil }
        var cumulativeValue = 0.0
        for segment in segments {
            cumulativeValue += segment.valueEUR.vaultDouble
            if selectedAngle <= cumulativeValue {
                return segment
            }
        }
        return segments.last
    }

    private func toggleSelection(
        of segment: AnalysisAllocationSegment
    ) {
        if selectedSegment?.id == segment.id {
            selectedAngle = nil
            return
        }

        var lowerBound = 0.0
        for candidate in segments {
            let upperBound = lowerBound + candidate.valueEUR.vaultDouble
            if candidate.id == segment.id {
                selectedAngle = (lowerBound + upperBound) / 2
                return
            }
            lowerBound = upperBound
        }
    }

    private var leadingShare: Decimal {
        selectedBreakdown.items.first?.sharePercentage ?? 0
    }

    private var concentrationRatio: Double {
        min(1, max(0, leadingShare.vaultDouble / 100))
    }

    private var concentrationTitle: String.LocalizationValue {
        switch leadingShare {
        case 75...:
            "analysis.allocation.concentration.very-high"
        case 50...:
            "analysis.allocation.concentration.high"
        case 35...:
            "analysis.allocation.concentration.balanced"
        default:
            "analysis.allocation.concentration.diversified"
        }
    }

    private var concentrationSystemImage: String {
        leadingShare >= 50 ? "scope" : "circle.grid.3x3.fill"
    }

    private var concentrationTint: Color {
        leadingShare >= 50 ? theme.goldBright : theme.cobaltBright
    }

    private var concentrationDetail: String {
        guard let leading = selectedBreakdown.items.first else { return "" }
        return AnalysisCopy.formatted(
            "analysis.allocation.concentration.detail",
            selectedKind.localizedName(for: leading.key),
            VaultFormatters.percentage(
                leading.sharePercentage ?? 0,
                maximumFractionDigits: 0
            )
        )
    }

    private var coverageCount: String {
        let coverage = selectedBreakdown.coverage
        return "\(coverage.includedRecordCount)/\(coverage.totalRecordCount)"
    }

    private var coveragePercentage: String {
        guard let value = selectedBreakdown.coverage.valuePercentage else {
            return "—"
        }
        return VaultFormatters.percentage(value, maximumFractionDigits: 0)
    }
}

private struct AnalysisAllocationSegment: Identifiable {
    let id: String
    let key: String?
    let valueEUR: Decimal
    let sharePercentage: Decimal?
    let recordCount: Int?
    let isUnassigned: Bool

    func localizedName(kind: AnalysisBreakdownKind) -> String {
        guard let key else {
            return AnalysisCopy.string("analysis.allocation.unassigned")
        }
        return kind.localizedName(for: key)
    }
}

private extension AnalysisBreakdownKind {
    var systemImage: String {
        switch self {
        case .categories:
            "square.grid.2x2.fill"
        case .locations:
            "mappin.and.ellipse"
        case .metals:
            "circle.hexagongrid.fill"
        }
    }

    func localizedName(for key: String) -> String {
        let localizationKey: String?
        switch self {
        case .categories:
            guard let category = AssetCategory(rawValue: key) else {
                return key
            }
            return AnalysisCopy.string(category.analysisAllocationLabel)
        case .locations:
            return key
        case .metals:
            localizationKey = MarketMetal(rawValue: key)?
                .preciousMetal
                .localizationKey
        }

        guard let localizationKey else { return key }
        let localized = String(localized: LocalizedStringResource(
            String.LocalizationValue(localizationKey)
        ))
        return localized == localizationKey ? key : localized
    }
}
