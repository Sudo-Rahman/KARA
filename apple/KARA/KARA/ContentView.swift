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

    var body: some View {
        Group {
            switch flow.destination {
            case let .onboarding(mode):
                OnboardingView(
                    mode: mode,
                    onFinish: finishOnboarding,
                    onSkip: skipOnboarding
                )
            case .addFirstItem:
                FirstAssetHandoffView(onReplay: flow.replayOnboarding)
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

#Preview {
    ContentView()
        .environment(
            AppFlow(
                defaults: UserDefaults(suiteName: "kara.preview")!,
                arguments: ["-KARAResetOnboarding"]
            )
        )
        .environment(KaraTheme())
}
