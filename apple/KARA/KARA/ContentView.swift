//
//  ContentView.swift
//  KARA
//
//  Created by sr-71 on 7/18/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(AppFlow.self) private var flow
    @Environment(KaraTheme.self) private var theme
    @Environment(PrivacyPreferences.self) private var privacyPreferences
    @Environment(AIFormAutofillPreferences.self) private var aiFormAutofillPreferences
    @Environment(AppLockPreferences.self) private var appLockPreferences
    @Environment(AppLockController.self) private var appLockController
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

            if showsPrivacyShield {
                PrivacyShieldView(
                    isLocked: appLockController.isLocked
                )
            }
        }
        .background(theme.background)
        .tint(theme.goldBright)
        .preferredColorScheme(.dark)
        .animation(.easeOut(duration: 0.35), value: flow.destination)
        .task {
            guard scenePhase == .active else { return }
            await appLockController.didBecomeActive()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task {
                    await appLockController.didBecomeActive()
                }
            case .background:
                appLockController.didEnterBackground()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }

    private var showsPrivacyShield: Bool {
        if appLockController.isLocked {
            return true
        }

        guard scenePhase != .active else { return false }
        return privacyPreferences.hidesSensitiveValues
            || appLockPreferences.isEnabled
            || appLockController.isAuthenticating
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
            aiFormAutofillPreferences.disable()
            flow.skipOnboarding()
        case .replay:
            flow.finishReplay()
        }
    }
}

private struct PrivacyShieldView: View {
    @Environment(KaraTheme.self) private var theme

    let isLocked: Bool

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
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityIdentifier("app-lock.shield")
    }

    private var accessibilityLabel: LocalizedStringKey {
        isLocked
            ? "app-lock.shield.accessibility-label"
            : "privacy.shield.accessibility-label"
    }
}
