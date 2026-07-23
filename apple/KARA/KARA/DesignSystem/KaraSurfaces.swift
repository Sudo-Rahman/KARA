import SwiftUI

struct KaraCard<Content: View>: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private let contentPadding: CGFloat
    private let minHeight: CGFloat?
    private let content: Content

    init(
        padding: CGFloat = KaraSpacing.medium,
        minHeight: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        contentPadding = padding
        self.minHeight = minHeight
        self.content = content()
    }

    var body: some View {
        content
            .padding(contentPadding)
            .frame(
                maxWidth: .infinity,
                minHeight: minHeight,
                alignment: .topLeading
            )
            .background {
                cardBackground
            }
            .shadow(
                color: theme.cobaltBright.opacity(hasIncreasedContrast ? 0.14 : 0.08),
                radius: 14,
                y: 6
            )
    }

    @ViewBuilder
    private var cardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        if reduceTransparency {
            shape
                .fill(theme.surface)
                .overlay {
                    cardReflections(shape)
                }
                .overlay {
                    cardBorder(shape)
                }
                .overlay {
                    cardInnerHighlight(shape)
                }
        } else {
            shape
                .fill(surfaceGradient)
                .overlay {
                    cardReflections(shape)
                }
                .overlay {
                    cardBorder(shape)
                }
                .overlay {
                    cardInnerHighlight(shape)
                }
                .glassEffect(
                    .clear
                        .tint(theme.cobalt.opacity(hasIncreasedContrast ? 0.10 : 0.05))
                        .interactive(),
                    in: .rect(cornerRadius: 20),

                )
        }
    }

    private func cardBorder(
        _ shape: RoundedRectangle
    ) -> some View {
        shape
            .stroke(borderGradient, lineWidth: borderWidth)
            .allowsHitTesting(false)
    }

    private func cardReflections(
        _ shape: RoundedRectangle
    ) -> some View {
        ZStack {
            shape.fill(goldReflection)
            shape.fill(cobaltReflection)
        }
        .allowsHitTesting(false)
    }

    private func cardInnerHighlight(
        _ shape: RoundedRectangle
    ) -> some View {
        shape
            .inset(by: 1)
            .stroke(innerHighlightGradient, lineWidth: 1)
            .blur(radius: 0.35)
            .allowsHitTesting(false)
    }

    private var surfaceGradient: LinearGradient {
        LinearGradient(
            colors: [
                theme.surface.opacity(hasIncreasedContrast ? 1 : 0.92),
                Color.black.opacity(hasIncreasedContrast ? 0.76 : 0.54),
                theme.surface.opacity(hasIncreasedContrast ? 0.96 : 0.84),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderGradient: LinearGradient {
        return LinearGradient(
            colors: [
                Color.white.opacity(hasIncreasedContrast ? 0.52 : 0.24),
                theme.goldBright.opacity(hasIncreasedContrast ? 0.36 : 0.16),
                theme.cobaltBright.opacity(hasIncreasedContrast ? 0.48 : 0.22),
                Color.white.opacity(hasIncreasedContrast ? 0.28 : 0.10),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var goldReflection: RadialGradient {
        RadialGradient(
            colors: [
                theme.goldBright.opacity(hasIncreasedContrast ? 0.14 : 0.06),
                theme.gold.opacity(hasIncreasedContrast ? 0.06 : 0.03),
                .clear,
            ],
            center: .topLeading,
            startRadius: 0,
            endRadius: 260
        )
    }

    private var cobaltReflection: RadialGradient {
        RadialGradient(
            colors: [
                theme.cobaltBright.opacity(hasIncreasedContrast ? 0.12 : 0.07),
                theme.cobalt.opacity(hasIncreasedContrast ? 0.05 : 0.025),
                .clear,
            ],
            center: .bottomTrailing,
            startRadius: 0,
            endRadius: 300
        )
    }

    private var innerHighlightGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(hasIncreasedContrast ? 0.24 : 0.14),
                theme.goldBright.opacity(hasIncreasedContrast ? 0.10 : 0.05),
                .clear,
                theme.cobaltBright.opacity(hasIncreasedContrast ? 0.10 : 0.05),
                Color.white.opacity(hasIncreasedContrast ? 0.08 : 0.03),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var hasIncreasedContrast: Bool {
        colorSchemeContrast == .increased
    }

    private var borderWidth: CGFloat {
        hasIncreasedContrast ? 1.5 : 1
    }
}

struct KaraMetric<Value: View, Detail: View>: View {
    @Environment(KaraTheme.self) private var theme

    private let title: LocalizedStringKey
    private let systemImage: String?
    private let value: Value
    private let detail: Detail

    init(
        title: LocalizedStringKey,
        systemImage: String? = nil,
        @ViewBuilder value: () -> Value,
        @ViewBuilder detail: () -> Detail
    ) {
        self.title = title
        self.systemImage = systemImage
        self.value = value()
        self.detail = detail()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.small) {
            HStack(alignment: .firstTextBaseline, spacing: KaraSpacing.small) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: KaraSpacing.small)

                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.goldBright)
                        .accessibilityHidden(true)
                }
            }

            value
                .font(theme.displayFont(size: 26, relativeTo: .title2))
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)

            detail
                .font(.caption)
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension KaraMetric where Detail == EmptyView {
    init(
        title: LocalizedStringKey,
        systemImage: String? = nil,
        @ViewBuilder value: () -> Value
    ) {
        self.init(
            title: title,
            systemImage: systemImage,
            value: value,
            detail: EmptyView.init
        )
    }
}

#Preview("KARA metrics") {
    VStack(spacing: KaraSpacing.medium) {
        KaraCard {
            KaraMetric(title: "preview.metric.estimated-value", systemImage: "sparkles") {
                Text("18,420 €")
                    .monospacedDigit()
            } detail: {
                Text("preview.metric.updated-today")
            }
        }

        KaraCard {
            KaraMetric(title: "preview.metric.unrealized-gain", systemImage: "chart.line.uptrend.xyaxis") {
                Text("+2,115 €")
                    .monospacedDigit()
                    .foregroundStyle(.green)
            }
        }
    }
    .padding(KaraSpacing.large)
    .background(Color("KaraVoid").ignoresSafeArea())
    .environment(KaraTheme())
    .preferredColorScheme(.dark)
}
