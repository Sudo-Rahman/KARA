import SwiftUI

struct OnboardingPage: View {
    let step: OnboardingStep
    let isActive: Bool

    var body: some View {
        switch step {
        case .revelation:
            OnboardingScrollablePage(alignment: .bottom) {
                OnboardingHeading(step: step, isHero: true)
                    .padding(.bottom, KaraSpacing.large)
            }
        case .inventory:
            OnboardingScrollablePage {
                VStack(alignment: .leading, spacing: KaraSpacing.large) {
                    OnboardingHeading(step: step)
                    OnboardingAssetIllustration(isActive: isActive)
                    OnboardingInventoryWorkflow()
                }
            }
        case .valuation:
            OnboardingScrollablePage {
                VStack(alignment: .leading, spacing: KaraSpacing.large) {
                    OnboardingHeading(step: step)
                    OnboardingValuationIllustration(isActive: isActive)
                }
            }
        case .permissions:
            OnboardingScrollablePage {
                VStack(alignment: .leading, spacing: KaraSpacing.large) {
                    OnboardingHeading(step: step)
                    OnboardingPermissionsChecklist()
                }
            }
        case .intelligence:
            OnboardingScrollablePage {
                VStack(alignment: .leading, spacing: KaraSpacing.large) {
                    OnboardingHeading(step: step)
                    OnboardingIntelligenceIllustration(isActive: isActive)
                    AIOnboardingConsentControl()
                }
            }
        }
    }
}

private struct OnboardingScrollablePage<Content: View>: View {
    let alignment: Alignment
    let content: Content

    init(
        alignment: Alignment = .center,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical) {
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(
                        minHeight: max(0, proxy.size.height - 16),
                        alignment: alignment
                    )
                    .padding(.horizontal, KaraSpacing.large)
                    .padding(.vertical, KaraSpacing.small)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

private struct OnboardingHeading: View {
    @Environment(KaraTheme.self) private var theme
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 33

    let step: OnboardingStep
    var isHero = false

    var body: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.medium) {
            VStack(alignment: .leading, spacing: 2) {
                Text(step.title)
                    .foregroundStyle(theme.ink)

                Text(step.accentTitle)
                    .foregroundStyle(theme.goldBright)
            }
            .font(
                theme.displayFont(
                    size: isHero ? min(titleSize * 1.14, 48) : titleSize,
                    relativeTo: .largeTitle
                )
            )
            .tracking(-1.1)
            .lineSpacing(-2)

            Text(step.body)
                .font(.subheadline)
                .foregroundStyle(theme.muted)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 520, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct OnboardingInventoryWorkflow: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: KaraSpacing.small) {
                workflowStep(
                    "onboarding.inventory.workflow.capture",
                    systemImage: "camera.viewfinder"
                )
                arrow
                workflowStep(
                    "onboarding.inventory.workflow.complete",
                    systemImage: "slider.horizontal.3"
                )
                arrow
                workflowStep(
                    "onboarding.inventory.workflow.preserve",
                    systemImage: "doc.badge.ellipsis"
                )
            }

            VStack(alignment: .leading, spacing: KaraSpacing.small) {
                workflowStep(
                    "onboarding.inventory.workflow.capture",
                    systemImage: "camera.viewfinder"
                )
                workflowStep(
                    "onboarding.inventory.workflow.complete",
                    systemImage: "slider.horizontal.3"
                )
                workflowStep(
                    "onboarding.inventory.workflow.preserve",
                    systemImage: "doc.badge.ellipsis"
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("onboarding.inventory.workflow.accessibility"))
    }

    private func workflowStep(
        _ title: LocalizedStringKey,
        systemImage: String
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(2)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, KaraSpacing.small)
            .foregroundStyle(Color("KaraCobaltBright"))
            .background(
                Color("KaraCobalt").opacity(0.15),
                in: .rect(cornerRadius: 12)
            )
    }

    private var arrow: some View {
        Image(systemName: "chevron.right")
            .font(.caption2.weight(.bold))
            .foregroundStyle(Color("KaraMuted"))
            .accessibilityHidden(true)
    }
}

private struct AIOnboardingConsentControl: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(AIFormAutofillPreferences.self) private var preferences

    var body: some View {
        @Bindable var preferences = preferences

        VStack(alignment: .leading, spacing: KaraSpacing.small) {
            Toggle(
                "onboarding.intelligence.toggle.title",
                isOn: $preferences.isEnabled
            )
            .font(.subheadline.weight(.semibold))
            .karaCobaltControlSurface()
            .accessibilityIdentifier("onboarding.intelligence.toggle")

            Text("onboarding.intelligence.toggle.detail")
                .font(.caption)
                .foregroundStyle(theme.muted)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
