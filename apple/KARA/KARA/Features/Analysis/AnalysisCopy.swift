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

extension PortfolioAnalyticsPeriod {
    var analysisLabel: LocalizedStringResource {
        switch self {
        case .threeMonths:
            AnalysisCopy.resource("analysis.period.three-months")
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
        case .oneYear:
            .twelveMonths
        case .all:
            .all
        }
    }
}
