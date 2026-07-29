import SwiftUI

struct OnboardingAssetIllustration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isActive: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { proxy in
                OnboardingFadedHeroArtwork(
                    name: "AssetKindCoinHero",
                    leadingFadeEnd: 0.38,
                    trailingFadeStart: 0.90,
                    bottomFadeStart: 0.88
                )
                    .frame(width: proxy.size.width * 0.42)
                    .position(
                        x: proxy.size.width * 0.24,
                        y: proxy.size.height * 0.32
                    )
                    .rotationEffect(.degrees(isRevealed ? -7 : -16))
                    .offset(x: isRevealed ? 0 : -32)

                OnboardingFadedHeroArtwork(
                    name: "AssetKindBarHero",
                    leadingFadeEnd: 0.34,
                    trailingFadeStart: 0.90,
                    bottomFadeStart: 0.88
                )
                    .frame(width: proxy.size.width * 0.50)
                    .position(
                        x: proxy.size.width * 0.72,
                        y: proxy.size.height * 0.34
                    )
                    .rotationEffect(.degrees(isRevealed ? 6 : 15))
                    .offset(x: isRevealed ? 0 : 36)

                OnboardingFadedHeroArtwork(
                    name: "AssetKindJewelryHero",
                    leadingFadeEnd: 0.40,
                    trailingFadeStart: 0.91,
                    bottomFadeStart: 0.90
                )
                    .frame(width: proxy.size.width * 0.38)
                    .position(
                        x: proxy.size.width * 0.58,
                        y: proxy.size.height * 0.57
                    )
                    .scaleEffect(isRevealed ? 1 : 0.84)
            }
            .opacity(isRevealed ? 1 : 0)

            sampleAssetCard
                .offset(y: isRevealed ? 0 : 18)
                .opacity(isRevealed ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 246)
        .animation(revealAnimation, value: isRevealed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("onboarding.inventory.example.accessibility"))
    }

    private var sampleAssetCard: some View {
        OnboardingDemoSurface {
            HStack(spacing: KaraSpacing.medium) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.title2)
                    .foregroundStyle(Color("KaraGoldBright"))
                    .frame(width: 44, height: 44)
                    .background(
                        Color("KaraGold").opacity(0.13),
                        in: .rect(cornerRadius: 12)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                    HStack(spacing: KaraSpacing.small) {
                        Text("onboarding.example.label")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color("KaraCobaltBright"))

                        Text("onboarding.inventory.example.name")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color("KaraInk"))
                            .lineLimit(1)
                    }

                    Text("onboarding.inventory.example.detail")
                        .font(.caption)
                        .foregroundStyle(Color("KaraMuted"))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Text("onboarding.inventory.example.value")
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Color("KaraGoldBright"))
            }
        }
    }

    private var isRevealed: Bool {
        reduceMotion || isActive
    }

    private var revealAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.46)
    }
}

private struct OnboardingFadedHeroArtwork: View {
    let name: String
    let leadingFadeEnd: CGFloat
    let trailingFadeStart: CGFloat
    let bottomFadeStart: CGFloat

    var body: some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .mask(horizontalFade)
            .mask(verticalFade)
            .compositingGroup()
    }

    private var horizontalFade: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .white, location: leadingFadeEnd),
                .init(color: .white, location: trailingFadeStart),
                .init(color: .clear, location: 1),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var verticalFade: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .white, location: 0.12),
                .init(color: .white, location: bottomFadeStart),
                .init(color: .clear, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct OnboardingValuationIllustration: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isActive: Bool

    var body: some View {
        OnboardingDemoSurface {
            VStack(alignment: .leading, spacing: KaraSpacing.medium) {
                HStack(alignment: .firstTextBaseline, spacing: KaraSpacing.small) {
                    VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                        Text("onboarding.example.label")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(theme.cobaltBright)

                        Text("onboarding.valuation.example.metric")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(theme.muted)
                    }

                    Spacer(minLength: KaraSpacing.small)

                    Text("onboarding.valuation.example.coverage")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(theme.cobaltBright)
                }

                Text("onboarding.valuation.example.value")
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(theme.ink)

                Text("onboarding.valuation.example.gain")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.green)

                OnboardingTrendChart(progress: isRevealed ? 1 : 0)
                    .frame(height: 94)

                HStack(spacing: KaraSpacing.small) {
                    valuationMetric(
                        title: "onboarding.valuation.example.assets",
                        value: "onboarding.valuation.example.assets.value"
                    )
                    valuationMetric(
                        title: "onboarding.valuation.example.documents",
                        value: "onboarding.valuation.example.documents.value"
                    )
                }

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: KaraSpacing.small),
                        GridItem(.flexible(), spacing: KaraSpacing.small),
                    ],
                    alignment: .leading,
                    spacing: KaraSpacing.small
                ) {
                    capability("onboarding.valuation.capability.performance")
                    capability("onboarding.valuation.capability.allocation")
                    capability("onboarding.valuation.capability.simulation")
                    capability("onboarding.valuation.capability.reports")
                }
            }
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.62),
            value: isRevealed
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("onboarding.valuation.example")
    }

    private func valuationMetric(
        title: LocalizedStringKey,
        value: LocalizedStringKey
    ) -> some View {
        VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(theme.muted)

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(KaraSpacing.small)
        .background(
            theme.cobalt.opacity(0.10),
            in: .rect(cornerRadius: 10)
        )
    }

    private func capability(_ title: LocalizedStringKey) -> some View {
        Label(title, systemImage: "checkmark.circle.fill")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(theme.cobaltBright)
            .lineLimit(2)
    }

    private var isRevealed: Bool {
        reduceMotion || isActive
    }
}

struct OnboardingIntelligenceIllustration: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isActive: Bool

    var body: some View {
        ZStack {
            receipt
                .rotationEffect(.degrees(isRevealed ? -5 : -11))
                .offset(
                    x: isRevealed ? -72 : -96,
                    y: isRevealed ? 0 : 14
                )

            suggestions
                .offset(
                    x: isRevealed ? 56 : 92,
                    y: isRevealed ? 10 : 28
                )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.48),
            value: isRevealed
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("onboarding.intelligence.example.accessibility"))
    }

    private var receipt: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.small) {
            Text("KARA")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.black.opacity(0.62))

            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(Color.black.opacity(index == 0 ? 0.28 : 0.15))
                    .frame(
                        width: index.isMultiple(of: 2) ? 86 : 112,
                        height: 5
                    )
            }
        }
        .padding(KaraSpacing.medium)
        .frame(width: 150, height: 154, alignment: .topLeading)
        .background(
            Color(red: 0.93, green: 0.92, blue: 0.87),
            in: .rect(cornerRadius: 14)
        )
        .shadow(color: .black.opacity(0.35), radius: 16, y: 9)
    }

    private var suggestions: some View {
        OnboardingDemoSurface {
            VStack(alignment: .leading, spacing: KaraSpacing.small) {
                Label(
                    "onboarding.intelligence.example.title",
                    systemImage: "sparkles"
                )
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.cobaltBright)

                suggestion(
                    "onboarding.intelligence.example.type",
                    value: "onboarding.intelligence.example.type.value"
                )
                suggestion(
                    "onboarding.intelligence.example.metal",
                    value: "onboarding.intelligence.example.metal.value"
                )
                suggestion(
                    "onboarding.intelligence.example.weight",
                    value: "onboarding.intelligence.example.weight.value"
                )
            }
            .frame(width: 146)
        }
        .shadow(color: .black.opacity(0.30), radius: 16, y: 9)
    }

    private func suggestion(
        _ title: LocalizedStringKey,
        value: LocalizedStringKey
    ) -> some View {
        HStack(spacing: KaraSpacing.small) {
            Text(title)
                .foregroundStyle(theme.muted)
            Spacer(minLength: 0)
            Text(value)
                .foregroundStyle(theme.ink)
        }
        .font(.caption2)
    }

    private var isRevealed: Bool {
        reduceMotion || isActive
    }
}

private struct OnboardingTrendChart: View {
    @Environment(KaraTheme.self) private var theme

    let progress: CGFloat

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { _ in
                    Divider()
                        .overlay(theme.muted.opacity(0.10))
                    Spacer()
                }
            }

            OnboardingTrendShape()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [theme.cobalt, theme.cobaltBright],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(
                        lineWidth: 3,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .shadow(color: theme.cobaltBright.opacity(0.36), radius: 7)
        }
        .accessibilityHidden(true)
    }
}

private struct OnboardingTrendShape: Shape {
    func path(in rect: CGRect) -> Path {
        let points: [CGPoint] = [
            CGPoint(x: 0.00, y: 0.76),
            CGPoint(x: 0.14, y: 0.67),
            CGPoint(x: 0.27, y: 0.71),
            CGPoint(x: 0.41, y: 0.50),
            CGPoint(x: 0.56, y: 0.55),
            CGPoint(x: 0.70, y: 0.34),
            CGPoint(x: 0.84, y: 0.40),
            CGPoint(x: 1.00, y: 0.15),
        ]

        var path = Path()
        guard let first = points.first else { return path }
        path.move(
            to: CGPoint(
                x: rect.minX + (first.x * rect.width),
                y: rect.minY + (first.y * rect.height)
            )
        )

        for point in points.dropFirst() {
            path.addLine(
                to: CGPoint(
                    x: rect.minX + (point.x * rect.width),
                    y: rect.minY + (point.y * rect.height)
                )
            )
        }
        return path
    }
}

private struct OnboardingDemoSurface<Content: View>: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(KaraSpacing.medium)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        reduceTransparency
                            ? AnyShapeStyle(theme.surface)
                            : AnyShapeStyle(
                                LinearGradient(
                                    colors: [
                                        theme.surface.opacity(0.96),
                                        Color.black.opacity(0.72),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(hasIncreasedContrast ? 0.38 : 0.16),
                                theme.cobaltBright.opacity(
                                    hasIncreasedContrast ? 0.46 : 0.22
                                ),
                                theme.goldBright.opacity(
                                    hasIncreasedContrast ? 0.28 : 0.12
                                ),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: hasIncreasedContrast ? 1.5 : 1
                    )
            }
    }

    private var hasIncreasedContrast: Bool {
        colorSchemeContrast == .increased
    }
}
