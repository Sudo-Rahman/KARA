import SwiftUI

struct OnboardingView: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(OnboardingPermissionsModel.self) private var permissions
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    let mode: OnboardingMode
    let onFinish: (OnboardingMode) -> Void
    let onSkip: (OnboardingMode) -> Void

    @State private var flowState = OnboardingFlowState()
    @State private var pageID: String? = OnboardingStep.revelation.id
    @State private var primaryFeedback = 0

    var body: some View {
        VStack(spacing: 0) {
            topBar
            pager
                .frame(maxHeight: .infinity)
            footer
        }
        .safeAreaPadding(.top, KaraSpacing.xSmall)
        .safeAreaPadding(.bottom, KaraSpacing.small)
        .background {
            OnboardingBackdrop(
                step: flowState.step,
                reduceMotion: reduceMotion
            )
        }
        .sensoryFeedback(.selection, trigger: flowState.step)
        .sensoryFeedback(.impact(weight: .light), trigger: primaryFeedback)
        .accessibilityAction(named: Text("onboarding.skip")) {
            onSkip(mode)
        }
        .onChange(of: pageID) { _, newPageID in
            guard
                let newPageID,
                let step = OnboardingStep.allCases.first(where: {
                    $0.id == newPageID
                })
            else {
                return
            }
            flowState.select(step)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, flowState.step == .permissions else {
                return
            }
            Task {
                await permissions.refresh()
            }
        }
        .task(id: flowState.step) {
            guard flowState.step == .permissions else { return }
            await permissions.refresh()
        }
    }

    private var topBar: some View {
        HStack(spacing: KaraSpacing.medium) {
            Text("KARA")
                .font(.system(size: 16, weight: .semibold, design: .serif))
                .tracking(2.4)
                .foregroundStyle(theme.goldBright)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: KaraSpacing.medium)

            Button("onboarding.skip") {
                onSkip(mode)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(theme.ink)
            .frame(minWidth: 64, minHeight: 44)
            .accessibilityIdentifier("onboarding.skip")
        }
        .padding(.horizontal, KaraSpacing.large)
        .frame(minHeight: 52)
    }

    private var pager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(OnboardingStep.allCases) { step in
                    OnboardingPage(
                        step: step,
                        isActive: flowState.step == step
                    )
                    .containerRelativeFrame(.horizontal)
                    .id(step.id)
                    .accessibilityIdentifier("onboarding.page.\(step.id)")
                }
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $pageID)
        .accessibilityIdentifier("onboarding.pager")
    }

    private var footer: some View {
        VStack(spacing: 12) {
            progressIndicator

            Button(action: advance) {
                Text(flowState.step.action)
            }
            .buttonStyle(KaraPrimaryActionButtonStyle())
            .accessibilityIdentifier("onboarding.primary.action")
        }
        .padding(.horizontal, 18)
        .padding(.top, KaraSpacing.small)
    }

    private var progressIndicator: some View {
        HStack(spacing: KaraSpacing.small) {
            ForEach(OnboardingStep.allCases) { step in
                Capsule()
                    .fill(
                        step == flowState.step
                            ? theme.goldBright
                            : Color.white.opacity(0.24)
                    )
                    .frame(
                        width: step == flowState.step ? 22 : 7,
                        height: 7
                    )
            }
        }
        .animation(
            .easeOut(
                duration: OnboardingMotionProfile(
                    reduceMotion: reduceMotion
                ).transitionDuration
            ),
            value: flowState.step
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(flowState.step.progressText))
        .accessibilityIdentifier("onboarding.progress")
    }

    private func advance() {
        primaryFeedback += 1

        switch flowState.advance() {
        case let .advanced(next):
            withAnimation(KaraMotion.stepTransition(reduceMotion: reduceMotion)) {
                pageID = next.id
            }
        case .completed:
            onFinish(mode)
        }
    }
}

private struct OnboardingBackdrop: View {
    @Environment(KaraTheme.self) private var theme

    let step: OnboardingStep
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            theme.background

            if step == .revelation {
                Image("OnboardingBackgroundRevelation")
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .transition(.opacity)

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.04),
                        Color.black.opacity(0.10),
                        theme.background.opacity(0.92),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            } else {
                RadialGradient(
                    colors: [
                        theme.cobalt.opacity(0.20),
                        theme.background.opacity(0),
                    ],
                    center: .topTrailing,
                    startRadius: 0,
                    endRadius: 420
                )

                RadialGradient(
                    colors: [
                        theme.gold.opacity(0.08),
                        theme.background.opacity(0),
                    ],
                    center: .bottomLeading,
                    startRadius: 0,
                    endRadius: 360
                )
            }
        }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.38),
            value: step
        )
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
