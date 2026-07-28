import Charts
import SwiftUI
import UIKit

struct ValuationHistoryCard: View {
    @Environment(KaraTheme.self) private var theme

    @State private var selectedPeriod: PortfolioHistoryPeriod = .twelveMonths

    let history: [PortfolioHistoryPoint]
    let showsUnknownPurchaseDates: Bool
    let titleKey: String
    let unknownPurchaseDatesKey: String
    let accessibilityIdentifier: String
    let accessibilityLabelKey: (PortfolioHistoryPeriod) -> String

    init(
        history: [PortfolioHistoryPoint],
        showsUnknownPurchaseDates: Bool,
        titleKey: String = "vault.history.title",
        unknownPurchaseDatesKey: String = "vault.history.unknown-dates",
        accessibilityIdentifier: String = "vault.history",
        accessibilityLabelKey: @escaping (PortfolioHistoryPeriod) -> String = { $0.accessibilityLabelKey }
    ) {
        self.history = history
        self.showsUnknownPurchaseDates = showsUnknownPurchaseDates
        self.titleKey = titleKey
        self.unknownPurchaseDatesKey = unknownPurchaseDatesKey
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityLabelKey = accessibilityLabelKey
    }

    var body: some View {
        let points = selectedPeriod.filter(history, asOf: historyAsOf)

        KaraCard {
            VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                VaultSectionHeader(LocalizedStringKey(titleKey))

                Picker("vault.history.period", selection: $selectedPeriod) {
                    ForEach(PortfolioHistoryPeriod.allCases, id: \.self) { period in
                        Text(LocalizedStringKey(period.localizationKey))
                            .tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .frame(minHeight: 44)
                .tint(theme.goldBright)
                .accessibilityIdentifier("\(accessibilityIdentifier).period")

                if points.count >= 2,
                   let domain = chartDomain(for: points)
                {
                    SensitiveValue {
                        PortfolioHistoryChart(
                            points: points,
                            domain: domain,
                            period: selectedPeriod,
                            accessibilityLabelKey: accessibilityLabelKey(selectedPeriod),
                            accessibilityIdentifier: "\(accessibilityIdentifier).chart"
                        )
                    }
                } else {
                    VStack(alignment: .leading, spacing: KaraSpacing.small) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.title2)
                            .foregroundStyle(theme.goldBright)

                        Text("vault.history.not-enough-data")
                            .font(.subheadline)
                            .foregroundStyle(theme.muted)
                    }
                    .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
                }

                if showsUnknownPurchaseDates {
                    Label(LocalizedStringKey(unknownPurchaseDatesKey), systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(theme.muted)
                }
            }
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var historyAsOf: Date {
        history.last?.date ?? .now
    }

    private func chartDomain(for points: [PortfolioHistoryPoint]) -> ClosedRange<Date>? {
        selectedPeriod.domain(for: points, asOf: historyAsOf)
    }
}

struct PortfolioHistoryChart: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var rawSelectedDate: Date?
    @State private var selectionFeedbackTrigger = 0

    let points: [PortfolioHistoryPoint]
    let domain: ClosedRange<Date>
    let period: PortfolioHistoryPeriod
    let accessibilityLabelKey: String
    let accessibilityIdentifier: String

    var body: some View {
        Group {
            if reduceMotion {
                chart(laserProgress: nil)
            } else {
                KeyframeAnimator(
                    initialValue: CGFloat(-0.18),
                    repeating: true
                ) { progress in
                    chart(laserProgress: progress)
                } keyframes: { _ in
                    KeyframeTrack(\.self) {
                        LinearKeyframe(1.18, duration: 1.35)
                        LinearKeyframe(1.18, duration: 2.65)
                        MoveKeyframe(-0.18)
                    }
                }
            }
        }
        .frame(height: 190)
        .sensoryFeedback(.selection, trigger: selectionFeedbackTrigger)
        .onChange(of: selectedPoint?.id) { oldValue, newValue in
            guard let newValue, newValue != oldValue else { return }
            selectionFeedbackTrigger += 1
        }
        .onChange(of: period) {
            endInspection()
        }
        .onDisappear {
            endInspection()
        }
        .accessibilityLabel(Text(LocalizedStringKey(accessibilityLabelKey)))
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var selectedPoint: PortfolioHistoryPoint? {
        guard let rawSelectedDate else { return nil }
        return PortfolioHistorySelection.nearestPoint(to: rawSelectedDate, in: points)
    }

    private func chart(laserProgress: CGFloat?) -> some View {
        Chart {
            ForEach(points) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.valueEUR.vaultDouble)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [theme.cobaltBright.opacity(0.30), theme.cobalt.opacity(0.01)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.valueEUR.vaultDouble)
                )
                .foregroundStyle(theme.goldBright)
                .lineStyle(.init(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.linear)

                if let laserProgress {
                    LineMark(
                        x: .value("Laser date", point.date),
                        y: .value("Laser value", point.valueEUR.vaultDouble)
                    )
                    .foregroundStyle(laserGradient(progress: laserProgress, opacity: 0.24))
                    .lineStyle(.init(lineWidth: 8, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.linear)

                    LineMark(
                        x: .value("Laser core date", point.date),
                        y: .value("Laser core value", point.valueEUR.vaultDouble)
                    )
                    .foregroundStyle(laserGradient(progress: laserProgress, opacity: 0.94))
                    .lineStyle(.init(lineWidth: 2.8, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.linear)
                }

                if point.isCurrent {
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.valueEUR.vaultDouble)
                    )
                    .foregroundStyle(theme.goldBright)
                    .symbolSize(58)
                }
            }

            if let selectedPoint {
                RuleMark(x: .value("Selected date", selectedPoint.date))
                    .foregroundStyle(theme.goldBright.opacity(0.58))
                    .lineStyle(.init(lineWidth: 1, dash: [3, 5], dashPhase: 1))
                    .zIndex(-1)
                    .annotation(
                        position: .top,
                        spacing: KaraSpacing.small,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        selectionCapsule(for: selectedPoint)
                    }

                RuleMark(y: .value("Selected value", selectedPoint.valueEUR.vaultDouble))
                    .foregroundStyle(theme.cobaltBright.opacity(0.46))
                    .lineStyle(.init(lineWidth: 1, dash: [3, 5], dashPhase: 1))
                    .zIndex(-1)

                PointMark(
                    x: .value("Selected date", selectedPoint.date),
                    y: .value("Selected value", selectedPoint.valueEUR.vaultDouble)
                )
                .foregroundStyle(theme.goldBright.opacity(0.16))
                .symbolSize(270)

                PointMark(
                    x: .value("Selected date", selectedPoint.date),
                    y: .value("Selected value", selectedPoint.valueEUR.vaultDouble)
                )
                .foregroundStyle(theme.goldBright)
                .symbolSize(92)

                PointMark(
                    x: .value("Selected date", selectedPoint.date),
                    y: .value("Selected value", selectedPoint.valueEUR.vaultDouble)
                )
                .foregroundStyle(.white)
                .symbolSize(24)
            }
        }
        .chartLegend(.hidden)
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXScale(domain: domain)
        .chartXAxis {
            if period == .all {
                AxisMarks(values: allHistoryAxisDates) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date, format: .dateTime.year())
                                .font(.caption2)
                                .foregroundStyle(theme.muted)
                        }
                    }
                }
            } else {
                AxisMarks(values: .stride(by: .month, count: period.axisMonthStride)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            if isInitialMonth(date) || Calendar.current.component(.month, from: date) == 1 {
                                Text(date, format: .dateTime.month(.abbreviated).year())
                                    .font(.caption2)
                                    .foregroundStyle(theme.muted)
                            } else {
                                Text(date, format: .dateTime.month(.abbreviated))
                                    .font(.caption2)
                                    .foregroundStyle(theme.muted)
                            }
                        }
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                    .foregroundStyle(theme.muted.opacity(0.16))
                AxisValueLabel {
                    if let amount = value.as(Double.self) {
                        Text(VaultFormatters.currency(Decimal(amount)))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(theme.muted)
                    }
                }
            }
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                ChartLongPressOverlay(
                    minimumDuration: 0.2,
                    allowableMovement: 10,
                    onChanged: { location in
                        selectDate(at: location, proxy: proxy, geometry: geometry)
                    },
                    onEnded: endInspection
                )
            }
        }
    }

    private func selectDate(
        at location: CGPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) {
        guard let plotFrame = proxy.plotFrame else { return }
        let frame = geometry[plotFrame]
        let plotX = location.x - frame.minX
        guard plotX >= 0,
              plotX <= frame.width,
              let date: Date = proxy.value(atX: plotX)
        else {
            return
        }

        rawSelectedDate = date
    }

    private func endInspection() {
        rawSelectedDate = nil
    }

    private func laserGradient(progress: CGFloat, opacity: Double) -> LinearGradient {
        let halfWidth: CGFloat = 0.15
        return LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: theme.goldBright.opacity(opacity * 0.35), location: 0.34),
                .init(color: .white.opacity(opacity), location: 0.50),
                .init(color: theme.goldBright.opacity(opacity * 0.70), location: 0.61),
                .init(color: .clear, location: 1),
            ],
            startPoint: UnitPoint(x: progress - halfWidth, y: 0.5),
            endPoint: UnitPoint(x: progress + halfWidth, y: 0.5)
        )
    }

    private func selectionCapsule(for point: PortfolioHistoryPoint) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(VaultFormatters.currency(point.valueEUR))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(theme.ink)

            Text(point.date, format: .dateTime.day().month(.abbreviated).year())
                .font(.caption2.weight(.medium))
                .foregroundStyle(theme.muted)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(theme.surface.opacity(0.96), in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [theme.goldBright.opacity(0.68), theme.cobaltBright.opacity(0.28)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: theme.goldBright.opacity(0.16), radius: 10, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("\(accessibilityIdentifier).selection")
    }

    private var allHistoryAxisDates: [Date] {
        let calendar = Calendar.current
        let firstYear = calendar.component(.year, from: domain.lowerBound)
        let lastYear = calendar.component(.year, from: domain.upperBound)
        let yearSpan = max(0, lastYear - firstYear)
        let yearStep = max(1, Int(ceil(Double(max(yearSpan, 1)) / 4)))
        var dates = [domain.lowerBound]

        if yearSpan > 0 {
            for year in stride(from: firstYear + yearStep, to: lastYear, by: yearStep) {
                if let date = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) {
                    dates.append(date)
                }
            }
            dates.append(domain.upperBound)
        }

        return dates
    }

    private func isInitialMonth(_ date: Date) -> Bool {
        Calendar.current.isDate(date, equalTo: domain.lowerBound, toGranularity: .month)
    }
}

private struct ChartLongPressOverlay: UIViewRepresentable {
    let minimumDuration: TimeInterval
    let allowableMovement: CGFloat
    let onChanged: (CGPoint) -> Void
    let onEnded: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChanged: onChanged, onEnded: onEnded)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear

        let recognizer = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        recognizer.minimumPressDuration = minimumDuration
        recognizer.allowableMovement = allowableMovement
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        recognizer.delegate = context.coordinator
        view.addGestureRecognizer(recognizer)

        context.coordinator.recognizer = recognizer
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
        context.coordinator.recognizer?.minimumPressDuration = minimumDuration
        context.coordinator.recognizer?.allowableMovement = allowableMovement
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        weak var recognizer: UILongPressGestureRecognizer?
        var onChanged: (CGPoint) -> Void
        var onEnded: () -> Void

        init(
            onChanged: @escaping (CGPoint) -> Void,
            onEnded: @escaping () -> Void
        ) {
            self.onChanged = onChanged
            self.onEnded = onEnded
        }

        @objc func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            switch recognizer.state {
            case .began, .changed:
                guard let view = recognizer.view else { return }
                onChanged(recognizer.location(in: view))
            case .ended, .cancelled, .failed:
                onEnded()
            case .possible:
                break
            @unknown default:
                onEnded()
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

nonisolated enum PortfolioHistorySelection {
    static func nearestPoint(
        to date: Date,
        in points: [PortfolioHistoryPoint]
    ) -> PortfolioHistoryPoint? {
        points.reduce(nil) { nearest, candidate in
            guard let nearest else { return candidate }

            let candidateDistance = abs(candidate.date.timeIntervalSince(date))
            let nearestDistance = abs(nearest.date.timeIntervalSince(date))

            if candidateDistance < nearestDistance {
                return candidate
            }
            if candidateDistance == nearestDistance, candidate.date > nearest.date {
                return candidate
            }
            return nearest
        }
    }
}

extension PortfolioHistoryPeriod {
    var localizationKey: String {
        switch self {
        case .threeMonths: "vault.history.period.3-months"
        case .sixMonths: "vault.history.period.6-months"
        case .twelveMonths: "vault.history.period.12-months"
        case .all: "vault.history.period.all"
        }
    }

    var accessibilityLabelKey: String {
        switch self {
        case .threeMonths: "vault.history.accessibility-label.3-months"
        case .sixMonths: "vault.history.accessibility-label.6-months"
        case .twelveMonths: "vault.history.accessibility-label.12-months"
        case .all: "vault.history.accessibility-label.all"
        }
    }

    var assetAccessibilityLabelKey: String {
        switch self {
        case .threeMonths: "asset-detail.history.accessibility-label.3-months"
        case .sixMonths: "asset-detail.history.accessibility-label.6-months"
        case .twelveMonths: "asset-detail.history.accessibility-label.12-months"
        case .all: "asset-detail.history.accessibility-label.all"
        }
    }

    var axisMonthStride: Int {
        switch self {
        case .threeMonths: 1
        case .sixMonths: 2
        case .twelveMonths: 3
        case .all: 1
        }
    }
}
