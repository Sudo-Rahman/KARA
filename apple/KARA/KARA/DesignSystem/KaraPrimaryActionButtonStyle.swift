import SwiftUI

enum KaraMotion {
    static let reducedDuration: TimeInterval = 0.18
    static let stepDuration: TimeInterval = 0.65
    static let stepBounce: Double = 0.12
    static let controlResponseDuration: TimeInterval = 0.16

    static func stepTransition(reduceMotion: Bool) -> Animation {
        reduceMotion
            ? .easeOut(duration: reducedDuration)
            : .spring(duration: stepDuration, bounce: stepBounce)
    }

    static func controlResponse(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: controlResponseDuration)
    }
}

struct KaraPrimaryActionButtonStyle: ButtonStyle {
    let isLoading: Bool

    init(isLoading: Bool = false) {
        self.isLoading = isLoading
    }

    func makeBody(configuration: Configuration) -> some View {
        KaraPrimaryActionButtonBody(
            label: configuration.label,
            isPressed: configuration.isPressed,
            isLoading: isLoading
        )
    }
}

extension ButtonStyle where Self == KaraPrimaryActionButtonStyle {
    static var karaPrimaryAction: KaraPrimaryActionButtonStyle {
        KaraPrimaryActionButtonStyle()
    }

    static func karaPrimaryAction(
        isLoading: Bool
    ) -> KaraPrimaryActionButtonStyle {
        KaraPrimaryActionButtonStyle(isLoading: isLoading)
    }
}

private struct KaraPrimaryActionButtonBody<Label: View>: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.isEnabled) private var isEnabled
    @ScaledMetric(relativeTo: .headline) private var labelFontSize: CGFloat = 19

    let label: Label
    let isPressed: Bool
    let isLoading: Bool

    var body: some View {
        label
            .font(.system(size: labelFontSize, weight: .semibold, design: .default))
            .foregroundStyle(theme.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .multilineTextAlignment(.center)
            .frame(
                maxWidth: .infinity,
                minHeight: minimumHeight
            )
            .contentShape(.capsule)
            .background {
                ZStack {
                    if reduceTransparency {
                        Capsule()
                            .fill(theme.surface)
                    }

                    Capsule()
                        .fill(surfaceGradient)
                }
            }
            .overlay {
                Capsule()
                    .stroke(borderGradient, lineWidth: borderWidth)
                    .allowsHitTesting(false)
            }
            .modifier(
                KaraPrimaryActionGlassEffect(
                    isInteractive: isEnabled && !isLoading,
                    tintOpacity: glassTintOpacity
                )
            )
            .shadow(
                color: theme.cobaltBright.opacity(shadowOpacity),
                radius: isPressed ? 6 : 9,
                y: isPressed ? 1 : 3
            )
            .scaleEffect(reduceMotion || !isPressed ? 1 : 0.985)
            .opacity(contentOpacity)
            .saturation(isEnabled || isLoading ? 1 : 0.55)
            .animation(
                KaraMotion.controlResponse(reduceMotion: reduceMotion),
                value: isPressed
            )
            .allowsHitTesting(!isLoading)
    }

    private var minimumHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 64 : 52
    }

    private var hasIncreasedContrast: Bool {
        colorSchemeContrast == .increased
    }

    private var surfaceGradient: LinearGradient {
        LinearGradient(
            colors: [
                theme.cobalt.opacity(hasIncreasedContrast ? 0.24 : 0.16),
                Color.black.opacity(hasIncreasedContrast ? 0.68 : 0.42),
                theme.cobalt.opacity(hasIncreasedContrast ? 0.18 : 0.10),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(hasIncreasedContrast ? 0.88 : 0.60),
                theme.cobaltBright.opacity(hasIncreasedContrast ? 0.90 : 0.58),
                Color.white.opacity(hasIncreasedContrast ? 0.48 : 0.18),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var glassTintOpacity: Double {
        hasIncreasedContrast ? 0.18 : 0.10
    }

    private var borderWidth: CGFloat {
        hasIncreasedContrast ? 1.5 : 1.1
    }

    private var shadowOpacity: Double {
        guard isEnabled || isLoading else { return 0.08 }
        if isPressed { return hasIncreasedContrast ? 0.24 : 0.14 }
        return hasIncreasedContrast ? 0.34 : 0.22
    }

    private var contentOpacity: Double {
        guard isEnabled || isLoading else { return 0.48 }
        return isPressed ? 0.94 : 1
    }
}

private struct KaraPrimaryActionGlassEffect: ViewModifier {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let isInteractive: Bool
    let tintOpacity: Double

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceTransparency {
            content
        } else {
            content.glassEffect(
                .clear
                    .tint(theme.cobalt.opacity(tintOpacity))
                    .interactive(isInteractive),
                in: .capsule
            )
        }
    }
}

#Preview("KARA primary actions") {
    VStack(spacing: KaraSpacing.large) {
        Button("classification.continue") {}
            .buttonStyle(.karaPrimaryAction)

        Button {} label: {
            ProgressView()
        }
        .buttonStyle(.karaPrimaryAction(isLoading: true))
        .disabled(true)

        Button("preview.primary-action.unavailable") {}
            .buttonStyle(.karaPrimaryAction)
            .disabled(true)
    }
    .padding(KaraSpacing.large)
    .background(Color("KaraVoid"))
    .environment(KaraTheme())
    .preferredColorScheme(.dark)
}
