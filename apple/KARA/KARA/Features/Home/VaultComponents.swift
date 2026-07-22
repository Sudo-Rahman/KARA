import Foundation
import SwiftUI
import UIKit

enum VaultFormatters {
    static func currency(
        _ value: Decimal,
        code: String = "EUR",
        showsPositiveSign: Bool = false,
        maximumFractionDigits: Int = 0
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .currency
        formatter.currencyCode = code
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.usesGroupingSeparator = true
        if showsPositiveSign, value > 0 {
            formatter.positivePrefix = "+"
        }
        return formatter.string(from: NSDecimalNumber(decimal: value))
            ?? NSDecimalNumber(decimal: value).stringValue
    }

    static func percentage(
        _ value: Decimal,
        showsPositiveSign: Bool = false,
        maximumFractionDigits: Int = 1
    ) -> String {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.usesGroupingSeparator = true
        if showsPositiveSign, value > 0 {
            formatter.positivePrefix = "+"
        }
        let number = formatter.string(from: NSDecimalNumber(decimal: value))
            ?? NSDecimalNumber(decimal: value).stringValue
        return "\(number)\u{00A0}%"
    }

    static func weight(_ value: Decimal, maximumFractionDigits: Int = 1) -> String {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.usesGroupingSeparator = true
        let number = formatter.string(from: NSDecimalNumber(decimal: value))
            ?? NSDecimalNumber(decimal: value).stringValue
        return "\(number)\u{00A0}g"
    }

    static func decimal(_ value: Decimal, maximumFractionDigits: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.locale = .current
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maximumFractionDigits
        formatter.usesGroupingSeparator = true
        return formatter.string(from: NSDecimalNumber(decimal: value))
            ?? NSDecimalNumber(decimal: value).stringValue
    }
}

struct VaultSectionHeader<Trailing: View>: View {
    @Environment(KaraTheme.self) private var theme

    private let title: LocalizedStringKey
    private let eyebrow: LocalizedStringKey?
    private let trailing: Trailing

    init(
        _ title: LocalizedStringKey,
        eyebrow: LocalizedStringKey? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.eyebrow = eyebrow
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: KaraSpacing.medium) {
            VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                if let eyebrow {
                    Text(eyebrow)
                        .font(.caption2.weight(.semibold))
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(theme.goldBright)
                }

                Text(title)
                    .font(theme.displayFont(size: 21, relativeTo: .title3))
                    .foregroundStyle(theme.ink)
            }

            Spacer(minLength: KaraSpacing.small)
            trailing
        }
    }
}

extension VaultSectionHeader where Trailing == EmptyView {
    init(_ title: LocalizedStringKey, eyebrow: LocalizedStringKey? = nil) {
        self.init(title, eyebrow: eyebrow, trailing: EmptyView.init)
    }
}

struct AssetArtworkView: View {
    @Environment(KaraTheme.self) private var theme

    let category: AssetCategory
    var photoData: Data?
    var size: CGFloat = 58

    var body: some View {
        Group {
            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(category.imageName)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(width: size, height: size)
        .background(theme.gold.opacity(0.08), in: .rect(cornerRadius: size * 0.28))
        .clipShape(.rect(cornerRadius: size * 0.28))
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }
}

struct VaultStatusPill: View {
    @Environment(KaraTheme.self) private var theme

    let text: LocalizedStringKey
    var systemImage: String?
    var tint: Color?

    var body: some View {
        Label {
            Text(text)
        } icon: {
            if let systemImage {
                Image(systemName: systemImage)
            }
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(tint ?? theme.muted)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background((tint ?? theme.cobalt).opacity(0.12), in: .capsule)
        .overlay {
            Capsule()
                .stroke((tint ?? theme.cobaltBright).opacity(0.25), lineWidth: 1)
        }
    }
}

struct PrivacyToolbarButton: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(PrivacyPreferences.self) private var privacyPreferences

    var body: some View {
        Button {
            privacyPreferences.toggle()
        } label: {
            Image(systemName: privacyPreferences.hidesSensitiveValues ? "eye.slash.fill" : "eye.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(theme.goldBright)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey(
            privacyPreferences.hidesSensitiveValues
                ? "privacy.action.reveal"
                : "privacy.action.conceal"
        )))
        .accessibilityHint(Text("privacy.action.hint"))
        .accessibilityIdentifier("privacy.toggle")
    }
}

func firstObjectPhotoData(
    for assetID: UUID,
    attachments: [AssetAttachment]
) -> Data? {
    attachments
        .lazy
        .filter { $0.assetID == assetID && $0.kind == .objectPhoto }
        .sorted { $0.createdAt > $1.createdAt }
        .first?
        .data
}

func newestObjectPhotoDataByAssetID(
    attachments: [AssetAttachment]
) -> [UUID: Data] {
    var newestAttachments: [UUID: AssetAttachment] = [:]

    for attachment in attachments where attachment.kind == .objectPhoto {
        guard let current = newestAttachments[attachment.assetID] else {
            newestAttachments[attachment.assetID] = attachment
            continue
        }

        if attachment.createdAt > current.createdAt {
            newestAttachments[attachment.assetID] = attachment
        }
    }

    return newestAttachments.mapValues(\.data)
}

extension Decimal {
    var vaultDouble: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
