import Foundation
import SwiftUI

enum KaraMarketNumericMotionStyle {
    case rolling
    case fading
}

enum KaraMarketNumericMotion {
    static let rollingDuration: TimeInterval = 0.45
    static let fadingDuration: TimeInterval = 0.15

    static func style(reduceMotion: Bool) -> KaraMarketNumericMotionStyle {
        reduceMotion ? .fading : .rolling
    }
}

extension View {
    func karaMarketNumericTransition(value: Decimal) -> some View {
        modifier(KaraMarketNumericTransitionModifier(value: value))
    }

    @ViewBuilder
    func karaMarketNumericTransition(value: Decimal?) -> some View {
        if let value {
            karaMarketNumericTransition(value: value)
        } else {
            self
        }
    }
}

private struct KaraMarketNumericTransitionModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let value: Decimal

    @ViewBuilder
    func body(content: Content) -> some View {
        switch KaraMarketNumericMotion.style(reduceMotion: reduceMotion) {
        case .rolling:
            content
                .contentTransition(.numericText(value: transitionValue))
                .animation(
                    .smooth(duration: KaraMarketNumericMotion.rollingDuration),
                    value: value
                )
                .transition(initialAppearanceTransition)

        case .fading:
            content
                .contentTransition(.opacity)
                .animation(
                    .easeOut(duration: KaraMarketNumericMotion.fadingDuration),
                    value: value
                )
                .transition(initialAppearanceTransition)
        }
    }

    private var transitionValue: Double {
        NSDecimalNumber(decimal: value).doubleValue
    }

    private var initialAppearanceTransition: AnyTransition {
        .opacity.animation(
            .easeOut(duration: KaraMarketNumericMotion.fadingDuration)
        )
    }
}
