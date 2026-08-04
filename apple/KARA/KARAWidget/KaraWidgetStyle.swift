import SwiftUI
import UIKit
import WidgetKit

enum KaraWidgetPalette {
    static let void = Color(red: 0.031, green: 0.035, blue: 0.043)
    static let surface = Color(red: 0.067, green: 0.082, blue: 0.110)
    static let ink = Color(red: 0.961, green: 0.953, blue: 0.937)
    static let muted = Color(red: 0.659, green: 0.675, blue: 0.706)
    static let cobalt = Color(red: 0.196, green: 0.388, blue: 1.000)
    static let cobaltBright = Color(red: 0.471, green: 0.647, blue: 1.000)
    static let gold = Color(red: 0.863, green: 0.682, blue: 0.282)
    static let goldBright = Color(red: 1.000, green: 0.890, blue: 0.631)
    static let positive = Color(red: 0.22, green: 0.82, blue: 0.43)
    static let negative = Color(red: 1.00, green: 0.36, blue: 0.40)
}

struct KaraWidgetStyle {
    let isFullColor: Bool
    let increasedContrast: Bool

    var ink: Color { isFullColor ? KaraWidgetPalette.ink : .primary }
    var muted: Color { isFullColor ? KaraWidgetPalette.muted : .secondary }
    var gold: Color { isFullColor ? KaraWidgetPalette.goldBright : .primary }
    var cobalt: Color { isFullColor ? KaraWidgetPalette.cobaltBright : .primary }
    var divider: Color {
        isFullColor
            ? KaraWidgetPalette.muted.opacity(increasedContrast ? 0.34 : 0.18)
            : .primary.opacity(increasedContrast ? 0.34 : 0.16)
    }

    func performance(_ value: Decimal) -> Color {
        guard isFullColor else { return value == 0 ? .secondary : .primary }
        if value > 0 { return KaraWidgetPalette.positive }
        if value < 0 { return KaraWidgetPalette.negative }
        return KaraWidgetPalette.muted
    }

    func metal(_ metal: KaraWidgetFavoriteMetal) -> Color {
        guard isFullColor else { return .primary }
        return switch metal {
        case .gold: KaraWidgetPalette.goldBright
        case .silver: Color(white: 0.84)
        case .platinum: KaraWidgetPalette.cobaltBright
        case .palladium: Color.cyan
        }
    }
}

struct KaraWidgetContainerBackground: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        if renderingMode == .fullColor {
            Group {
                if reduceTransparency {
                    ContainerRelativeShape()
                        .fill(KaraWidgetPalette.surface)
                } else {
                    ContainerRelativeShape()
                        .fill(surfaceGradient)
                }
            }
                .overlay {
                    ContainerRelativeShape()
                        .fill(goldReflection)
                }
                .overlay {
                    ContainerRelativeShape()
                        .fill(cobaltReflection)
                }
                .overlay {
                    edgeBorder
                }
        } else {
            // iOS 26 replaces removable widget backgrounds with its native
            // Liquid Glass/tinted material in accented and vibrant modes.
            Color.clear
        }
    }

    private var surfaceGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.052, green: 0.057, blue: 0.066),
                Color(red: 0.028, green: 0.032, blue: 0.039),
                Color(red: 0.031, green: 0.036, blue: 0.047),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var goldReflection: RadialGradient {
        RadialGradient(
            colors: [
                KaraWidgetPalette.goldBright.opacity(
                    colorSchemeContrast == .increased ? 0.14 : 0.08
                ),
                KaraWidgetPalette.gold.opacity(
                    colorSchemeContrast == .increased ? 0.07 : 0.035
                ),
                .clear,
            ],
            center: .topLeading,
            startRadius: 0,
            endRadius: 92
        )
    }

    private var cobaltReflection: RadialGradient {
        RadialGradient(
            colors: [
                KaraWidgetPalette.cobaltBright.opacity(
                    colorSchemeContrast == .increased ? 0.16 : 0.09
                ),
                KaraWidgetPalette.cobalt.opacity(
                    colorSchemeContrast == .increased ? 0.08 : 0.04
                ),
                .clear,
            ],
            center: .bottomTrailing,
            startRadius: 0,
            endRadius: 110
        )
    }

    private var edgeBorder: some View {
        ZStack {
            ContainerRelativeShape()
                .inset(by: 0.75)
                .stroke(
                    Color.white.opacity(
                        colorSchemeContrast == .increased ? 0.38 : 0.22
                    ),
                    lineWidth: colorSchemeContrast == .increased ? 1.1 : 0.8
                )

            edgeBloom(
                gradient: goldEdgeGradient,
                color: KaraWidgetPalette.goldBright,
                radius: colorSchemeContrast == .increased ? 7 : 6
            )

            edgeBloom(
                gradient: cobaltEdgeGradient,
                color: KaraWidgetPalette.cobaltBright,
                radius: colorSchemeContrast == .increased ? 8 : 7
            )

            ContainerRelativeShape()
                .inset(by: 0.8)
                .stroke(goldEdgeGradient, lineWidth: borderWidth)

            ContainerRelativeShape()
                .inset(by: 0.8)
                .stroke(cobaltEdgeGradient, lineWidth: borderWidth)
        }
        .accessibilityHidden(true)
    }

    private func edgeBloom(
        gradient: LinearGradient,
        color: Color,
        radius: CGFloat
    ) -> some View {
        ContainerRelativeShape()
            .inset(by: 0.9)
            .stroke(gradient, lineWidth: borderWidth + 0.9)
            .compositingGroup()
            .shadow(color: color.opacity(0.95), radius: 1.4)
            .shadow(color: color.opacity(0.78), radius: 3.2)
            .shadow(color: color.opacity(0.50), radius: radius)
    }

    private var goldEdgeGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(
                    color: KaraWidgetPalette.goldBright,
                    location: 0
                ),
                .init(
                    color: KaraWidgetPalette.goldBright,
                    location: 0.25
                ),
                .init(
                    color: KaraWidgetPalette.gold.opacity(0.70),
                    location: 0.38
                ),
                .init(
                    color: KaraWidgetPalette.gold.opacity(0.22),
                    location: 0.50
                ),
                .init(color: .clear, location: 0.62),
                .init(color: .clear, location: 1),
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var cobaltEdgeGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: .clear, location: 0),
                .init(color: .clear, location: 0.38),
                .init(
                    color: KaraWidgetPalette.cobalt.opacity(0.22),
                    location: 0.50
                ),
                .init(
                    color: KaraWidgetPalette.cobalt.opacity(0.70),
                    location: 0.62
                ),
                .init(
                    color: KaraWidgetPalette.cobaltBright,
                    location: 0.75
                ),
                .init(color: KaraWidgetPalette.cobaltBright, location: 1),
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderWidth: CGFloat {
        colorSchemeContrast == .increased ? 2.0 : 1.65
    }
}

extension Font {
    static func karaWidgetDisplay(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle
    ) -> Font {
        if UIFont(name: "Geologica", size: size) != nil {
            return .custom("Geologica", size: size, relativeTo: textStyle)
                .weight(.medium)
        }
        return .system(textStyle, design: .rounded)
            .weight(.semibold)
    }
}

enum KaraWidgetFormatters {
    static func number(
        _ value: Decimal,
        maximumFractionDigits: Int = 2
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSDecimalNumber(decimal: value))
            ?? NSDecimalNumber(decimal: value).stringValue
    }

    static func currency(
        _ value: Decimal,
        maximumFractionDigits: Int = 0,
        showsPositiveSign: Bool = false
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.usesGroupingSeparator = true
        if showsPositiveSign, value > 0 {
            formatter.positivePrefix = "+"
        }
        return formatter.string(from: NSDecimalNumber(decimal: value))
            ?? NSDecimalNumber(decimal: value).stringValue
    }

    static func percentage(
        _ value: Decimal,
        showsPositiveSign: Bool = true
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        formatter.usesGroupingSeparator = true
        if showsPositiveSign, value > 0 {
            formatter.positivePrefix = "+"
        }
        let number = formatter.string(from: NSDecimalNumber(decimal: value))
            ?? NSDecimalNumber(decimal: value).stringValue
        return "\(number)\u{00A0}%"
    }
}

extension KaraWidgetFavoriteMetal {
    var symbol: String {
        switch self {
        case .gold: "Au"
        case .silver: "Ag"
        case .platinum: "Pt"
        case .palladium: "Pd"
        }
    }

    var localizedName: LocalizedStringResource {
        switch self {
        case .gold: "widget.metal.gold"
        case .silver: "widget.metal.silver"
        case .platinum: "widget.metal.platinum"
        case .palladium: "widget.metal.palladium"
        }
    }
}
