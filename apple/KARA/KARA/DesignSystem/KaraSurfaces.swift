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
                color: theme.cobalt.opacity(colorSchemeContrast == .increased ? 0.24 : 0.16),
                radius: 18,
                y: 8
            )
    }

    @ViewBuilder
    private var cardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        if reduceTransparency {
            shape
                .fill(theme.surface)
                .overlay {
                    cardBorder(shape)
                }
        } else {
            shape
                .fill(surfaceGradient)
                .overlay {
                    cardBorder(shape)
                }
                .glassEffect(
                    .clear
                        .tint(theme.cobalt.opacity(0.07))
                        .interactive(),
                    in: .rect(cornerRadius: 20)
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

    private var surfaceGradient: LinearGradient {
        LinearGradient(
            colors: [
                theme.surface.opacity(0.96),
                theme.cobalt.opacity(0.10),
                theme.surface.opacity(0.88),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderGradient: LinearGradient {
        let emphasized = colorSchemeContrast == .increased

        return LinearGradient(
            colors: [
                Color.white.opacity(emphasized ? 0.40 : 0.20),
                theme.cobaltBright.opacity(emphasized ? 0.48 : 0.22),
                theme.gold.opacity(emphasized ? 0.36 : 0.14),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderWidth: CGFloat {
        colorSchemeContrast == .increased ? 1.5 : 1
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
