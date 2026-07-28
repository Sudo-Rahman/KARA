import Foundation
import SwiftUI

enum SalesCopy {
    static func resource(
        _ key: String.LocalizationValue
    ) -> LocalizedStringResource {
        LocalizedStringResource(key, table: "Sales")
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
