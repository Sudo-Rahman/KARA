import AppIntents
import SwiftUI
import WidgetKit

enum KaraWidgetConstants {
    static let kind = "com.karaprivate.KARA.widget.panorama"
}

@main
struct KARAWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: KaraWidgetConstants.kind,
            intent: KaraWidgetConfigurationIntent.self,
            provider: KaraWidgetTimelineProvider()
        ) { entry in
            KaraWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(
            LocalizedStringResource("widget.gallery.name")
        )
        .description(
            LocalizedStringResource("widget.gallery.description")
        )
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .containerBackgroundRemovable(true)
    }
}

nonisolated enum KaraWidgetFavoriteMetal: String, AppEnum, CaseIterable, Sendable {
    case gold
    case silver
    case platinum
    case palladium

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("widget.metal.type")
    )

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .gold: DisplayRepresentation(
            title: LocalizedStringResource("widget.metal.gold")
        ),
        .silver: DisplayRepresentation(
            title: LocalizedStringResource("widget.metal.silver")
        ),
        .platinum: DisplayRepresentation(
            title: LocalizedStringResource("widget.metal.platinum")
        ),
        .palladium: DisplayRepresentation(
            title: LocalizedStringResource("widget.metal.palladium")
        ),
    ]

    var sharedValue: KaraWidgetMetal {
        switch self {
        case .gold: .gold
        case .silver: .silver
        case .platinum: .platinum
        case .palladium: .palladium
        }
    }

    init(_ metal: KaraWidgetMetal) {
        switch metal {
        case .gold: self = .gold
        case .silver: self = .silver
        case .platinum: self = .platinum
        case .palladium: self = .palladium
        }
    }
}

nonisolated enum KaraWidgetViewMode: String, AppEnum, CaseIterable, Sendable {
    case market
    case portfolio

    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("widget.view.type")
    )

    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .market: DisplayRepresentation(
            title: LocalizedStringResource("widget.view.market")
        ),
        .portfolio: DisplayRepresentation(
            title: LocalizedStringResource("widget.view.portfolio")
        ),
    ]
}

struct KaraWidgetConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "widget.configuration.title"
    static let description = IntentDescription(
        "widget.configuration.description"
    )

    @Parameter(
        title: "widget.configuration.view",
        default: KaraWidgetViewMode.market
    )
    var viewMode: KaraWidgetViewMode

    @Parameter(
        title: "widget.configuration.metal",
        default: KaraWidgetFavoriteMetal.gold
    )
    var favoriteMetal: KaraWidgetFavoriteMetal

    init() {
        viewMode = .market
        favoriteMetal = .gold
    }

    init(
        viewMode: KaraWidgetViewMode = .market,
        favoriteMetal: KaraWidgetFavoriteMetal = .gold
    ) {
        self.viewMode = viewMode
        self.favoriteMetal = favoriteMetal
    }
}
