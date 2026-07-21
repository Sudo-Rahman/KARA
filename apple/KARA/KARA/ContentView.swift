//
//  ContentView.swift
//  KARA
//
//  Created by sr-71 on 7/18/26.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(AppFlow.self) private var flow
    @Environment(KaraTheme.self) private var theme
    @Environment(PrivacyPreferences.self) private var privacyPreferences
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Group {
                switch flow.destination {
                case let .onboarding(mode):
                    OnboardingView(
                        mode: mode,
                        onFinish: finishOnboarding,
                        onSkip: skipOnboarding
                    )
                case .main:
                    AppShellView()
                }
            }

            if privacyPreferences.hidesSensitiveValues && scenePhase != .active {
                PrivacyShieldView()
            }
        }
        .background(theme.background)
        .tint(theme.cobalt)
        .preferredColorScheme(.dark)
        .animation(.easeOut(duration: 0.35), value: flow.destination)
    }

    private func finishOnboarding(_ mode: OnboardingMode) {
        switch mode {
        case .firstLaunch:
            flow.completeOnboarding()
        case .replay:
            flow.finishReplay()
        }
    }

    private func skipOnboarding(_ mode: OnboardingMode) {
        switch mode {
        case .firstLaunch:
            flow.skipOnboarding()
        case .replay:
            flow.finishReplay()
        }
    }
}

private struct PrivacyShieldView: View {
    @Environment(KaraTheme.self) private var theme

    var body: some View {
        ZStack {
            theme.background.ignoresSafeArea()

            VStack(spacing: KaraSpacing.medium) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(theme.goldBright)

                Text("KARA")
                    .font(theme.displayFont(size: 28, relativeTo: .title2))
                    .foregroundStyle(theme.ink)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("privacy.shield.accessibility-label"))
    }
}

#Preview {
    ContentView()
        .environment(
            AppFlow(
                defaults: UserDefaults(suiteName: "kara.preview")!,
                arguments: ["-KARAResetOnboarding"]
            )
        )
        .environment(KaraTheme())
        .environment(PrivacyPreferences(defaults: UserDefaults(suiteName: "kara.preview.privacy")!))
        .modelContainer(
            for: [Asset.self, AssetAttachment.self, SavedSeller.self, StorageLocation.self],
            inMemory: true
        )
}
