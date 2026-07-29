import SwiftUI
import UIKit

struct OnboardingPermissionsChecklist: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(OnboardingPermissionsModel.self) private var permissions
    @Environment(\.openURL) private var openURL

    @State private var enabledFeedback = 0

    var body: some View {
        VStack(spacing: KaraSpacing.small) {
            ForEach(OnboardingPermissionKind.allCases, id: \.self) { permission in
                permissionRow(permission)
            }
        }
        .sensoryFeedback(.success, trigger: enabledFeedback)
    }

    @ViewBuilder
    private func permissionRow(
        _ permission: OnboardingPermissionKind
    ) -> some View {
        let state = permissions.state(for: permission)
        let action = permissions.action(for: permission)

        if action == .none {
            permissionRowLabel(permission, state: state)
                .accessibilityElement(children: .combine)
                .accessibilityValue(Text(state.accessibilityValue))
                .accessibilityHint(Text(accessibilityHint(for: action)))
                .accessibilityIdentifier(permission.accessibilityIdentifier)
        } else {
            Button {
                perform(action, for: permission)
            } label: {
                permissionRowLabel(permission, state: state)
            }
            .buttonStyle(.plain)
            .disabled(!canPerform(action, for: permission))
            .opacity(1)
            .accessibilityElement(children: .combine)
            .accessibilityValue(Text(state.accessibilityValue))
            .accessibilityHint(Text(accessibilityHint(for: action)))
            .accessibilityIdentifier(permission.accessibilityIdentifier)
        }
    }

    private func permissionRowLabel(
        _ permission: OnboardingPermissionKind,
        state: OnboardingPermissionState
    ) -> some View {
        HStack(spacing: KaraSpacing.medium) {
            Image(systemName: permission.systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.cobaltBright)
                .frame(width: 46, height: 46)
                .background(
                    theme.cobalt.opacity(0.16),
                    in: .rect(cornerRadius: 13)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                Text(permission.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.ink)

                Text(permission.detail)
                    .font(.caption)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: KaraSpacing.small)

            permissionState(state)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .background(
            theme.surface.opacity(0.92),
            in: .rect(cornerRadius: 17)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(
                    state == .enabled
                        ? Color.green.opacity(0.48)
                        : theme.cobaltBright.opacity(0.18),
                    lineWidth: state == .enabled ? 1.5 : 1
                )
        }
        .contentShape(.rect(cornerRadius: 17))
    }

    @ViewBuilder
    private func permissionState(
        _ state: OnboardingPermissionState
    ) -> some View {
        VStack(spacing: KaraSpacing.xSmall) {
            switch state {
            case .requesting:
                ProgressView()
                    .controlSize(.small)
                    .tint(theme.cobaltBright)
                    .frame(width: 30, height: 30)
            case .enabled:
                stateBox(
                    systemImage: "checkmark",
                    tint: .green,
                    isFilled: true
                )
            case .available:
                stateBox(
                    systemImage: nil,
                    tint: theme.cobaltBright,
                    isFilled: false
                )
            case .denied:
                stateBox(
                    systemImage: "gearshape.fill",
                    tint: theme.goldBright,
                    isFilled: false
                )
            case .unavailable:
                stateBox(
                    systemImage: "minus",
                    tint: theme.muted,
                    isFilled: false
                )
            case .failed:
                stateBox(
                    systemImage: "arrow.clockwise",
                    tint: theme.cobaltBright,
                    isFilled: false
                )
            }

            Text(state.shortLabel)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(state == .enabled ? Color.green : theme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 64)
    }

    private func stateBox(
        systemImage: String?,
        tint: Color,
        isFilled: Bool
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isFilled ? tint : Color.clear)
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(tint, lineWidth: 1.5)

            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(isFilled ? Color.black : tint)
            }
        }
        .frame(width: 30, height: 30)
    }

    private func canPerform(
        _ action: OnboardingPermissionAction,
        for permission: OnboardingPermissionKind
    ) -> Bool {
        guard action != .none else { return false }
        return permissions.activeRequest == nil
            || permissions.activeRequest == permission
    }

    private func perform(
        _ action: OnboardingPermissionAction,
        for permission: OnboardingPermissionKind
    ) {
        switch action {
        case .request:
            Task {
                await permissions.request(permission)
                if permissions.state(for: permission) == .enabled {
                    enabledFeedback += 1
                }
            }
        case .openSettings:
            guard let url = URL(string: UIApplication.openSettingsURLString) else {
                return
            }
            openURL(url)
        case .none:
            break
        }
    }

    private func accessibilityHint(
        for action: OnboardingPermissionAction
    ) -> LocalizedStringKey {
        switch action {
        case .request:
            "onboarding.permissions.action.request.hint"
        case .openSettings:
            "onboarding.permissions.action.settings.hint"
        case .none:
            "onboarding.permissions.action.none.hint"
        }
    }
}

private extension OnboardingPermissionKind {
    var title: LocalizedStringKey {
        switch self {
        case .camera:
            "onboarding.permissions.camera.title"
        case .notifications:
            "onboarding.permissions.notifications.title"
        case .appLock:
            "onboarding.permissions.app-lock.title"
        }
    }

    var detail: LocalizedStringKey {
        switch self {
        case .camera:
            "onboarding.permissions.camera.detail"
        case .notifications:
            "onboarding.permissions.notifications.detail"
        case .appLock:
            "onboarding.permissions.app-lock.detail"
        }
    }

    var systemImage: String {
        switch self {
        case .camera:
            "camera.viewfinder"
        case .notifications:
            "bell.badge.fill"
        case .appLock:
            "faceid"
        }
    }

    var accessibilityIdentifier: String {
        "onboarding.permissions.\(rawValue)"
    }
}

private extension OnboardingPermissionState {
    var shortLabel: LocalizedStringKey {
        switch self {
        case .available:
            "onboarding.permissions.state.configure"
        case .requesting:
            "onboarding.permissions.state.requesting"
        case .enabled:
            "onboarding.permissions.state.enabled"
        case .denied:
            "onboarding.permissions.state.settings"
        case .unavailable:
            "onboarding.permissions.state.unavailable"
        case .failed:
            "onboarding.permissions.state.retry"
        }
    }

    var accessibilityValue: LocalizedStringKey {
        switch self {
        case .available:
            "onboarding.permissions.state.available.accessibility"
        case .requesting:
            "onboarding.permissions.state.requesting.accessibility"
        case .enabled:
            "onboarding.permissions.state.enabled.accessibility"
        case .denied:
            "onboarding.permissions.state.denied.accessibility"
        case .unavailable:
            "onboarding.permissions.state.unavailable.accessibility"
        case .failed:
            "onboarding.permissions.state.failed.accessibility"
        }
    }
}
