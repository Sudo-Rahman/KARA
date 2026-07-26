import SwiftUI

struct OnboardingView: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let mode: OnboardingMode
    let onFinish: (OnboardingMode) -> Void
    let onSkip: (OnboardingMode) -> Void

    @State private var flowState = OnboardingFlowState()
    @State private var pageID: String? = OnboardingStep.revelation.id
    @State private var primaryFeedback = 0

    var body: some View {
        GeometryReader { proxy in
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout(in: proxy)
            } else {
                referenceLayout(in: proxy)
            }
        }
        .background {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                onboardingBackground
                    .offset(y: -24)
            }
        }
        .sensoryFeedback(.selection, trigger: flowState.step)
        .sensoryFeedback(.impact(weight: .light), trigger: primaryFeedback)
        .accessibilityAction(named: Text("onboarding.skip")) {
            onSkip(mode)
        }
        .onChange(of: pageID) { _, newPageID in
            guard
                let newPageID,
                let step = OnboardingStep.allCases.first(where: { $0.id == newPageID })
            else {
                return
            }
            flowState.select(step)
        }
    }

    private func referenceLayout(in proxy: GeometryProxy) -> some View {
        let width = proxy.size.width
        let height = proxy.size.height

        return ZStack {
            pager
                .frame(width: width, height: 236)
                .position(x: width / 2, y: height * 0.66)

            progressIndicator
                .position(
                    x: width / 2,
                    y: (height * 0.83) + (proxy.safeAreaInsets.bottom * 0.52)
                )

            primaryButton
                .frame(width: width - 36, height: 52)
                .position(
                    x: width / 2,
                    y: (height * 0.91) + (proxy.safeAreaInsets.bottom * 0.62)
                )
        }
    }

    private func accessibilityLayout(in proxy: GeometryProxy) -> some View {
        VStack(spacing: KaraSpacing.large) {
            Spacer(minLength: min(190, proxy.size.height * 0.25))

            pager
                .frame(maxHeight: .infinity)

            progressIndicator

            primaryButton
                .frame(minHeight: 64)
                .padding(.horizontal, 20)
        }
        .safeAreaPadding(.vertical, KaraSpacing.small)
        .background(Color.black.ignoresSafeArea())
    }

    private var onboardingBackground: some View {
        Image("OnboardingBackgroundRevelation")
            .resizable()
            .interpolation(.high)
            .scaledToFill()
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var pager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(OnboardingStep.allCases) { step in
                    OnboardingTitlePage(step: step)
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

    private var progressIndicator: some View {
        HStack(spacing: 12) {
            ForEach(OnboardingStep.allCases) { step in
                Circle()
                    .fill(
                        step == flowState.step
                            ? theme.goldBright
                            : Color.white.opacity(0.24)
                    )
                    .frame(width: 8, height: 8)
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

    private var primaryButton: some View {
        Button(action: advance) {
            Text(flowState.step.action)
        }
        .buttonStyle(KaraPrimaryActionButtonStyle())
        .accessibilityIdentifier("onboarding.primary.action")
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

private struct OnboardingTitlePage: View {
    @Environment(KaraTheme.self) private var theme

    let step: OnboardingStep

    var body: some View {
        Group {
            if step == .intelligence {
                ScrollView(.vertical) {
                    pageContent
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 2)
                }
                .scrollIndicators(.visible)
                .scrollBounceBehavior(.basedOnSize)
            } else {
                pageContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 39)
    }

    private var pageContent: some View {
        VStack(alignment: .leading, spacing: step == .intelligence ? KaraSpacing.medium : 1) {
            VStack(alignment: .leading, spacing: 1) {
                Text(step.title)
                    .foregroundStyle(theme.ink)
                    .lineSpacing(-7)

                Text(step.accentTitle)
                    .foregroundStyle(theme.goldBright)
            }
            .font(theme.displayFont(size: 39, relativeTo: .largeTitle))
            .tracking(-1.35)

            if step == .intelligence {
                AIOnboardingConsentControl()
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct AIOnboardingConsentControl: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(AIFormAutofillPreferences.self) private var preferences

    var body: some View {
        @Bindable var preferences = preferences

        VStack(alignment: .leading, spacing: KaraSpacing.small) {
            Text("onboarding.intelligence.body")
                .font(.subheadline)
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)

            Toggle("onboarding.intelligence.toggle.title", isOn: $preferences.isEnabled)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.ink)
                .tint(theme.cobaltBright)
                .accessibilityIdentifier("onboarding.intelligence.toggle")

            Text("onboarding.intelligence.toggle.detail")
                .font(.caption)
                .foregroundStyle(theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
