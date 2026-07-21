import SwiftUI

struct SensitiveValue<Content: View>: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(PrivacyPreferences.self) private var privacyPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Group {
            if privacyPreferences.hidesSensitiveValues {
                concealedContent
            } else {
                content
            }
        }
        .animation(
            KaraMotion.controlResponse(reduceMotion: reduceMotion),
            value: privacyPreferences.hidesSensitiveValues
        )
    }

    private var concealedContent: some View {
        content
            .hidden()
            .accessibilityHidden(true)
            .overlay {
                mask
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("privacy.value.masked"))
    }

    @ViewBuilder
    private var mask: some View {
        let shape = RoundedRectangle(cornerRadius: 7, style: .continuous)

        if reduceTransparency {
            shape
                .fill(theme.muted.opacity(colorSchemeContrast == .increased ? 0.52 : 0.36))
        } else {
            shape
                .fill(maskGradient)
                .glassEffect(
                    .regular.tint(theme.cobalt.opacity(0.14)),
                    in: .rect(cornerRadius: 7)
                )
        }
    }

    private var maskGradient: LinearGradient {
        LinearGradient(
            colors: [
                theme.muted.opacity(0.22),
                theme.cobalt.opacity(0.22),
                theme.muted.opacity(0.16),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

#Preview("Sensitive values — visible") {
    SensitiveValuePreview(hidesSensitiveValues: false)
}

#Preview("Sensitive values — hidden") {
    SensitiveValuePreview(hidesSensitiveValues: true)
}

private struct SensitiveValuePreview: View {
    @State private var preferences: PrivacyPreferences

    init(hidesSensitiveValues: Bool) {
        let suiteName = "kara.preview.privacy.\(hidesSensitiveValues)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set(hidesSensitiveValues, forKey: PrivacyPreferences.storageKey)
        _preferences = State(initialValue: PrivacyPreferences(defaults: defaults))
    }

    var body: some View {
        KaraCard {
            KaraMetric(title: "preview.metric.estimated-value", systemImage: "eye") {
                SensitiveValue {
                    Text("18,420 €")
                        .monospacedDigit()
                }
            } detail: {
                Text("preview.metric.updated-today")
            }
        }
        .padding(KaraSpacing.large)
        .background(Color("KaraVoid").ignoresSafeArea())
        .environment(KaraTheme())
        .environment(preferences)
        .preferredColorScheme(.dark)
    }
}
