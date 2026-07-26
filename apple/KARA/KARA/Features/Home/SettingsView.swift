import SwiftUI

struct SettingsView: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(AIFormAutofillPreferences.self) private var analysisPreferences

    var body: some View {
        @Bindable var analysisPreferences = analysisPreferences

        Form {
            Section("settings.ai.section") {
                Toggle(
                    "settings.ai.toggle",
                    isOn: $analysisPreferences.isEnabled
                )
                .accessibilityIdentifier("settings.ai.toggle")

                Text("settings.ai.detail")
                    .font(.footnote)
                    .foregroundStyle(theme.muted)

                Text("settings.ai.privacy")
                    .font(.caption)
                    .foregroundStyle(theme.muted)
            }
            .listRowBackground(theme.surface)
        }
        .formStyle(.grouped)
        .navigationTitle("settings.title")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(theme.background.ignoresSafeArea())
    }
}
