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

    let title: Text
    let detail: Text?

    init(_ title: LocalizedStringKey, detail: LocalizedStringKey? = nil) {
        self.title = Text(title)
        self.detail = detail.map { Text($0) }
    }

    init(_ title: Text, detail: Text? = nil) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
            title
                .font(.headline)
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)

            if let detail {
                detail
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

    let title: Text
    let helper: Text?

    init(_ title: LocalizedStringKey, helper: LocalizedStringKey? = nil) {
        self.title = Text(title)
        self.helper = helper.map { Text($0) }
    }

    init(_ title: Text, helper: Text? = nil) {
        self.title = title
        self.helper = helper
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            title
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.ink)

            if let helper {
                helper
                    .font(.caption)
                    .foregroundStyle(theme.muted)
            }
        }
    }
}

struct AssetFormSection<Content: View>: View {
    let title: Text
    let detail: Text?
    @ViewBuilder let content: Content

    init(
        title: Text,
        detail: Text? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.medium) {
            AssetSectionTitle(title, detail: detail)
            AssetFieldSurface { content }
        }
    }
}

struct AssetFieldGroup<Content: View>: View {
    let title: Text
    let helper: Text?
    @ViewBuilder let content: Content

    init(
        title: Text,
        helper: Text? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.helper = helper
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.small) {
            AssetFieldLabel(title, helper: helper)
            content
        }
    }
}

struct AssetGoldPurity: Identifiable, Sendable {
    let karat: Int
    let fineness: Double
    var id: Int { karat }

    static let common: [AssetGoldPurity] = [
        AssetGoldPurity(karat: 24, fineness: 999.9),
        AssetGoldPurity(karat: 22, fineness: 916.7),
        AssetGoldPurity(karat: 18, fineness: 750),
        AssetGoldPurity(karat: 14, fineness: 585),
        AssetGoldPurity(karat: 9, fineness: 375),
    ]
}

struct AssetGoldPurityPicker: View {
    @Environment(KaraTheme.self) private var theme

    let selectedKarat: Int?
    let onSelect: (AssetGoldPurity) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: KaraSpacing.small) {
                ForEach(AssetGoldPurity.common) { purity in
                    Button {
                        onSelect(purity)
                    } label: {
                        Text("\(purity.karat) ct")
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(selectedKarat == purity.karat ? theme.ink : theme.muted)
                            .padding(.horizontal, KaraSpacing.medium)
                            .frame(minHeight: 44)
                            .background(
                                selectedKarat == purity.karat
                                    ? theme.cobalt.opacity(0.24)
                                    : theme.background.opacity(0.70),
                                in: .capsule
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selectedKarat == purity.karat ? .isSelected : [])
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

struct AssetTagsEditor<FocusValue: Hashable>: View {
    @Environment(KaraTheme.self) private var theme

    @Binding var tags: [String]
    @Binding var pendingText: String
    let placeholder: String
    let commitAccessibilityLabel: String
    let removeAccessibilityLabel: String
    let accessibilityIdentifier: String
    let focusedField: FocusState<FocusValue?>.Binding
    let focusValue: FocusValue

    var body: some View {
        VStack(alignment: .leading, spacing: KaraSpacing.small) {
            if !tags.isEmpty {
                AssetTagFlowLayout(
                    horizontalSpacing: KaraSpacing.small,
                    verticalSpacing: KaraSpacing.small
                ) {
                    ForEach(tags, id: \.self) { tag in
                        AssetTagChip(
                            tag: tag,
                            removeAccessibilityLabel: removeAccessibilityLabel,
                            accessibilityIdentifier: "\(accessibilityIdentifier).remove.\(tag)"
                        ) {
                            tags.removeAll { $0 == tag }
                        }
                    }
                }
            }

            HStack(spacing: KaraSpacing.small) {
                TextField(placeholder, text: $pendingText)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .focused(focusedField, equals: focusValue)
                    .frame(minHeight: 46)
                    .accessibilityIdentifier(accessibilityIdentifier)
                    .onSubmit {
                        commitPendingText()
                        focusedField.wrappedValue = nil
                    }
                    .onChange(of: pendingText) { _, value in
                        commitTagsBeforeSeparator(in: value)
                    }

                if !pendingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button(action: commitPendingText) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.goldBright)
                    .frame(width: 32, height: 32)
                    .accessibilityLabel(commitAccessibilityLabel)
                    .accessibilityIdentifier("\(accessibilityIdentifier).commit")
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, KaraSpacing.xSmall)
        .background(Color.black.opacity(0.24), in: .rect(cornerRadius: 12))
        .onChange(of: focusedField.wrappedValue) { oldValue, newValue in
            guard oldValue == focusValue, newValue != focusValue else { return }
            commitPendingText()
        }
    }

    private func commitTagsBeforeSeparator(in value: String) {
        let components = value.components(separatedBy: CharacterSet(charactersIn: ",;\n"))
        guard components.count > 1 else { return }

        let pending = value.last.map { ",;\n".contains($0) ? "" : (components.last ?? "") } ?? ""
        commit(components.dropLast())
        pendingText = pending
    }

    private func commitPendingText() {
        commit([pendingText])
        pendingText = ""
    }

    private func commit<S: Sequence>(_ candidates: S) where S.Element == String {
        let newTags = AssetTagNormalizer.normalize(Array(candidates))
        guard !newTags.isEmpty else { return }
        tags = AssetTagNormalizer.normalize(tags + newTags)
    }
}

private struct AssetTagChip: View {
    @Environment(KaraTheme.self) private var theme

    let tag: String
    let removeAccessibilityLabel: String
    let accessibilityIdentifier: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: KaraSpacing.xSmall) {
            Text(verbatim: tag)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.ink)
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 24, height: 24)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.muted)
            .accessibilityLabel(removeAccessibilityLabel)
            .accessibilityValue(Text(verbatim: tag))
            .accessibilityIdentifier(accessibilityIdentifier)
        }
        .padding(.leading, 12)
        .padding(.trailing, KaraSpacing.xSmall)
        .background(theme.cobalt.opacity(0.22), in: .capsule)
        .overlay {
            Capsule()
                .stroke(theme.cobaltBright.opacity(0.42), lineWidth: 1)
        }
    }
}

private struct AssetTagFlowLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let availableWidth = proposal.width ?? .greatestFiniteMagnitude
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var widestRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let proposedRowWidth = rowWidth == 0
                ? size.width
                : rowWidth + horizontalSpacing + size.width

            if rowWidth > 0, proposedRowWidth > availableWidth {
                totalHeight += rowHeight + verticalSpacing
                widestRow = max(widestRow, rowWidth)
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth = proposedRowWidth
                rowHeight = max(rowHeight, size.height)
            }
        }

        totalHeight += rowHeight
        widestRow = max(widestRow, rowWidth)
        return CGSize(width: proposal.width ?? widestRow, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: x + size.width / 2, y: y + size.height / 2),
                anchor: .center,
                proposal: ProposedViewSize(size)
            )
            x += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

extension View {
    func assetInputSurface() -> some View {
        self
            .font(.body)
            .padding(.horizontal, 12)
            .frame(minHeight: 46)
            .background(Color.black.opacity(0.24), in: .rect(cornerRadius: 12))
    }

    func assetPickerSurface() -> some View {
        modifier(AssetPickerSurfaceModifier())
    }
}

private struct AssetPickerSurfaceModifier: ViewModifier {
    @Environment(KaraTheme.self) private var theme

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .padding(.horizontal, 12)
            .background(theme.cobalt.opacity(0.16), in: .rect(cornerRadius: 12))
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

    var heroImageName: String {
        switch self {
        case .bar: "AssetKindBarHero"
        case .coin: "AssetKindCoinHero"
        case .jewelry: "AssetKindJewelryHero"
        case .custom: "AssetKindOtherHero"
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
