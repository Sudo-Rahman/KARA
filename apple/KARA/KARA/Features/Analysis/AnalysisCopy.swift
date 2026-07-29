import Foundation
import SwiftUI

enum AnalysisCopy {
    static func resource(
        _ key: String.LocalizationValue
    ) -> LocalizedStringResource {
        LocalizedStringResource(key, table: "Analysis")
    }

    static func string(_ key: String.LocalizationValue) -> String {
        String(localized: resource(key))
    }

    static func text(_ key: String.LocalizationValue) -> Text {
        Text(resource(key))
    }

    static func formatted(
        _ key: String.LocalizationValue,
        _ arguments: CVarArg...
    ) -> String {
        String(
            format: string(key),
            locale: .current,
            arguments: arguments
        )
    }
}

nonisolated enum AnalysisSalesCountCopy {
    static func localizationKey(for count: Int) -> String {
        count == 1
            ? "analysis.sales.count.one"
            : "analysis.sales.count.other"
    }
}

nonisolated enum AnalysisAllocationCountCopy {
    static func recordLocalizationKey(for count: Int) -> String {
        count == 1
            ? "analysis.allocation.records.one"
            : "analysis.allocation.records.other"
    }

    static func groupLocalizationKey(for count: Int) -> String {
        count == 1
            ? "analysis.allocation.groups.one"
            : "analysis.allocation.groups.other"
    }
}

extension AssetCategory {
    var analysisAllocationLabel: String.LocalizationValue {
        switch self {
        case .bar:
            "analysis.allocation.category.bar"
        case .coin:
            "analysis.allocation.category.coin"
        case .jewelry:
            "analysis.allocation.category.jewelry"
        case .custom:
            "analysis.allocation.category.custom"
        }
    }
}

extension PortfolioAnalyticsPeriod {
    var analysisLabel: LocalizedStringResource {
        switch self {
        case .threeMonths:
            AnalysisCopy.resource("analysis.period.three-months")
        case .sixMonths:
            AnalysisCopy.resource("analysis.period.six-months")
        case .oneYear:
            AnalysisCopy.resource("analysis.period.one-year")
        case .all:
            AnalysisCopy.resource("analysis.period.all")
        }
    }

    var historyPeriod: PortfolioHistoryPeriod {
        switch self {
        case .threeMonths:
            .threeMonths
        case .sixMonths:
            .sixMonths
        case .oneYear:
            .twelveMonths
        case .all:
            .all
        }
    }
}
