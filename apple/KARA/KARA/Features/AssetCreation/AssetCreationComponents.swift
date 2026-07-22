import SwiftUI

struct AssetStepScaffold<Content: View, Footer: View>: View {
    @Environment(KaraTheme.self) private var theme

    let title: LocalizedStringKey
    let message: LocalizedStringKey?
    let onDismissKeyboard: (() -> Void)?
    @ViewBuilder let content: Content
    @ViewBuilder let footer: Footer

    init(
        title: LocalizedStringKey,
        message: LocalizedStringKey? = nil,
        onDismissKeyboard: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.title = title
        self.message = message
        self.onDismissKeyboard = onDismissKeyboard
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KaraSpacing.large) {
                AssetStepHeading(title: title, message: message)
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, KaraSpacing.large)
            .padding(.top, KaraSpacing.large)
            .padding(.bottom, KaraSpacing.xxLarge)
        }
        .background(theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .safeAreaBar(edge: .bottom, spacing: 0) {
            footer
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .padding(.horizontal, KaraSpacing.large)
                .padding(.top, KaraSpacing.xSmall)
                .padding(.bottom, KaraSpacing.xSmall)
        }
        .scrollEdgeEffectStyle(.hard, for: .top)
        .scrollDismissesKeyboard(.never)
        .gesture(
            TapGesture().onEnded { onDismissKeyboard?() },
            including: .gesture
        )
    }
}

struct AssetCreationHeader: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let step: AssetCreationStep
    let onBack: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                GlassEffectContainer(spacing: KaraSpacing.small) {
                    HStack {
                        if step != .objectPhoto {
                            headerButton(
                                title: "asset-flow.back",
                                systemImage: "chevron.backward",
                                identifier: "asset-flow.back",
                                action: onBack
                            )
                        } else {
                            Color.clear
                                .frame(width: 52, height: 52)
                                .accessibilityHidden(true)
                        }

                        Spacer(minLength: KaraSpacing.medium)

                        headerButton(
                            title: "asset-flow.cancel",
                            systemImage: "xmark",
                            identifier: "asset-flow.cancel",
                            action: onCancel
                        )
                    }
                }

                Text(step.navigationTitle)
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 64)
                    .contentTransition(.opacity)
                    .animation(
                        KaraMotion.controlResponse(reduceMotion: reduceMotion),
                        value: step
                    )
                    .accessibilityAddTraits(.isHeader)
            }
            .padding(.horizontal, KaraSpacing.large)
            .padding(.vertical, KaraSpacing.small)

            AssetCreationProgressView(step: step)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)

            Divider()
        }
        .background(theme.background)
    }

    private func headerButton(
        title: LocalizedStringKey,
        systemImage: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 21, weight: .semibold))
                .frame(width: 48, height: 48)
                .contentShape(.circle)
        }
        .buttonStyle(.karaSecondaryAction)
        .frame(width: 52, height: 52)
        .accessibilityLabel(title)
        .accessibilityIdentifier(identifier)
    }
}

struct AssetStepHeading: View {
    @Environment(KaraTheme.self) private var theme

    let title: LocalizedStringKey
    let message: LocalizedStringKey?

    var body: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.small) {
            Text(title)
                .font(theme.displayFont(size: 30, relativeTo: .largeTitle))
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)

            if let message {
                Text(message)
                    .font(.body)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("asset-step.heading")
    }
}

struct AssetCreationProgressView: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let step: AssetCreationStep

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: KaraSpacing.medium) {
                progressLabel
                segments
            }

            VStack(alignment: .leading, spacing: KaraSpacing.small) {
                progressLabel
                segments
            }
        }
        .padding(.horizontal, KaraSpacing.large)
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(progressLabelText)
        .accessibilityIdentifier("asset-flow.progress")
    }

    private var progressLabel: some View {
        progressLabelText
            .font(.caption.weight(.semibold))
            .foregroundStyle(theme.muted)
            .contentTransition(.numericText())
    }

    private var progressLabelText: Text {
        Text("asset-flow.progress \(step.rawValue + 1) \(AssetCreationStep.allCases.count)")
    }

    private var segments: some View {
        HStack(spacing: KaraSpacing.xSmall) {
            ForEach(AssetCreationStep.allCases) { candidate in
                Capsule()
                    .fill(candidate.rawValue <= step.rawValue ? theme.goldBright : theme.muted.opacity(0.20))
                    .frame(maxWidth: .infinity)
                    .frame(height: 3)
                    .animation(
                        KaraMotion.controlResponse(reduceMotion: reduceMotion),
                        value: step
                    )
            }
        }
        .frame(minWidth: 160)
    }
}

extension AssetCreationStep {
    var navigationTitle: LocalizedStringKey {
        switch self {
        case .objectPhoto: "asset-flow.object.navigation-title"
        case .invoice: "invoice.navigation-title"
        case .classification: "classification.navigation-title"
        case .characteristics: "characteristics.navigation-title"
        case .purchase: "purchase.navigation-title"
        case .summary: "summary.navigation-title"
        }
    }
}

struct AssetStepFooter<Secondary: View>: View {
    let title: LocalizedStringKey
    let systemImage: String?
    let isEnabled: Bool
    let action: () -> Void
    @ViewBuilder let secondary: Secondary

    init(
        title: LocalizedStringKey,
        systemImage: String? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void,
        @ViewBuilder secondary: () -> Secondary
    ) {
        self.title = title
        self.systemImage = systemImage
        self.isEnabled = isEnabled
        self.action = action
        self.secondary = secondary()
    }

    var body: some View {
        VStack(spacing: KaraSpacing.small) {
            Button(action: action) {
                Group {
                    if let systemImage {
                        Label(title, systemImage: systemImage)
                    } else {
                        Text(title)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(KaraPrimaryActionButtonStyle())
            .disabled(!isEnabled)

            secondary
        }
    }
}

extension AssetStepFooter where Secondary == EmptyView {
    init(
        title: LocalizedStringKey,
        systemImage: String? = nil,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.init(
            title: title,
            systemImage: systemImage,
            isEnabled: isEnabled,
            action: action,
            secondary: EmptyView.init
        )
    }
}

struct AssetSectionTitle: View {
    @Environment(KaraTheme.self) private var theme

    let title: LocalizedStringKey
    let detail: LocalizedStringKey?

    init(_ title: LocalizedStringKey, detail: LocalizedStringKey? = nil) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
            Text(title)
                .font(.headline)
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)

            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(theme.muted)
            }
        }
    }
}

struct AssetFieldSurface<Content: View>: View {
    @Environment(KaraTheme.self) private var theme

    @ViewBuilder let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.medium) {
            content
        }
        .padding(KaraSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: .rect(cornerRadius: 16))
    }
}

struct AssetFieldLabel: View {
    @Environment(KaraTheme.self) private var theme

    let title: LocalizedStringKey
    let helper: LocalizedStringKey?

    init(_ title: LocalizedStringKey, helper: LocalizedStringKey? = nil) {
        self.title = title
        self.helper = helper
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.ink)

            if let helper {
                Text(helper)
                    .font(.caption)
                    .foregroundStyle(theme.muted)
            }
        }
    }
}

struct AssetIssueBanner: View {
    @Environment(KaraTheme.self) private var theme

    let issue: AssetCreationIssue
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: KaraSpacing.small) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(theme.goldBright)
                .accessibilityHidden(true)

            Text(LocalizedStringKey(issue.localizationKey))
                .font(.subheadline)
                .foregroundStyle(theme.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("asset-flow.error.dismiss", systemImage: "xmark") {
                onDismiss()
            }
            .labelStyle(.iconOnly)
            .foregroundStyle(theme.muted)
        }
        .padding(KaraSpacing.medium)
        .background(theme.surface, in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(theme.gold.opacity(0.32), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("asset-flow.error")
    }
}

extension AssetCategory {
    var imageName: String {
        switch self {
        case .bar: "AssetKindBar"
        case .coin: "AssetKindCoin"
        case .jewelry: "AssetKindJewelry"
        case .custom: "AssetKindOther"
        }
    }

    var symbolName: String {
        switch self {
        case .bar: "square.stack.3d.up.fill"
        case .coin: "medal.fill"
        case .jewelry: "diamond.fill"
        case .custom: "shippingbox.fill"
        }
    }
}

extension PreciousMetal {
    var localizedKey: LocalizedStringKey {
        switch self {
        case .gold: "asset.metal.gold"
        case .silver: "asset.metal.silver"
        case .platinum: "asset.metal.platinum"
        case .palladium: "asset.metal.palladium"
        case .other: "asset.metal.other"
        }
    }

    var symbolName: String {
        switch self {
        case .gold: "sun.max.fill"
        case .silver: "moon.fill"
        case .platinum: "sparkles"
        case .palladium: "hexagon.fill"
        case .other: "circle.dashed"
        }
    }
}
