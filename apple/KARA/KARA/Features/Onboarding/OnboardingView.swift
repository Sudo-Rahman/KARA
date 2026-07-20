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
                .frame(width: width, height: 154)
                .position(x: width / 2, y: height * 0.68)

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
        VStack(alignment: .leading, spacing: 1) {
            Text(step.title)
                .foregroundStyle(theme.ink)
                .lineSpacing(-7)

            Text(step.accentTitle)
                .foregroundStyle(theme.goldBright)
        }
        .font(theme.displayFont(size: 39, relativeTo: .largeTitle))
        .tracking(-1.35)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 39)
    }
}

#Preview("Reference fidelity") {
    OnboardingView(mode: .firstLaunch, onFinish: { _ in }, onSkip: { _ in })
        .environment(KaraTheme())
        .preferredColorScheme(.dark)
}

#Preview("Accessibility text") {
    OnboardingView(mode: .firstLaunch, onFinish: { _ in }, onSkip: { _ in })
        .environment(KaraTheme())
        .environment(\.dynamicTypeSize, .accessibility3)
        .preferredColorScheme(.dark)
}
