import SwiftUI

struct FirstAssetHandoffView: View {
    @Environment(KaraTheme.self) private var theme

    let onReplay: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: KaraSpacing.large) {
                Spacer()

                Image(systemName: "plus.viewfinder")
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(theme.cobaltBright)
                    .accessibilityHidden(true)

                Text("handoff.title")
                    .font(theme.displayFont(size: 38, relativeTo: .largeTitle))
                    .tracking(-1.1)
                    .foregroundStyle(theme.ink)

                Text("handoff.body")
                    .font(.body)
                    .foregroundStyle(theme.muted)

                Spacer()

                Button("handoff.replay", action: onReplay)
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .accessibilityIdentifier("handoff.replay")
            }
            .padding(KaraSpacing.large)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("KARA")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    FirstAssetHandoffView(onReplay: {})
        .environment(KaraTheme())
        .preferredColorScheme(.dark)
}
