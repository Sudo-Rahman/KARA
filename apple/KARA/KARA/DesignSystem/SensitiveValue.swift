import SwiftUI

struct SensitiveValue<Content: View>: View {
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
            .blur(radius: reduceTransparency ? 8 : 11)
            .opacity(reduceTransparency ? 0.30 : 0.42)
            .accessibilityHidden(true)
            .overlay {
                if !reduceTransparency {
                    content
                        .blur(radius: 18)
                        .opacity(colorSchemeContrast == .increased ? 0.12 : 0.18)
                        .blendMode(.screen)
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("privacy.value.masked"))
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
