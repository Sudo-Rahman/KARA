//
//  KARAApp.swift
//  KARA
//
//  Created by sr-71 on 7/18/26.
//

import SwiftData
import SwiftUI

@main
struct KARAApp: App {
    @State private var flow = AppFlow()
    @State private var theme = KaraTheme()
    @State private var privacyPreferences = PrivacyPreferences()
    @State private var aiFormAutofillPreferences = AIFormAutofillPreferences()
    @State private var appLockPreferences: AppLockPreferences
    @State private var appLockController: AppLockController
    @State private var onboardingPermissionsModel: OnboardingPermissionsModel
    @State private var priceAlertNotificationNavigationInbox:
        PriceAlertNotificationNavigationInbox
    private let initialPersistencePhase: PersistencePhase

    init() {
        PriceAlertBestEffortBackgroundRefresh.register()
        initialPersistencePhase = KARAApplicationPersistence.load()

        let notificationNavigationInbox =
            PriceAlertNotificationNavigationInbox()
        _priceAlertNotificationNavigationInbox = State(
            initialValue: notificationNavigationInbox
        )
        SystemUserNotificationCenter.shared.installNavigationInbox(
            notificationNavigationInbox
        )

        let preferences = AppLockPreferences()
        let appLockController = AppLockController(preferences: preferences)
        _appLockPreferences = State(initialValue: preferences)
        _appLockController = State(initialValue: appLockController)
        _onboardingPermissionsModel = State(
            initialValue: OnboardingPermissionsModel(
                camera: .live,
                notifications: .live(),
                appLock: .live(controller: appLockController)
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            PersistenceHostView(initialPhase: initialPersistencePhase)
                .environment(flow)
                .environment(theme)
                .environment(privacyPreferences)
                .environment(aiFormAutofillPreferences)
                .environment(appLockPreferences)
                .environment(appLockController)
                .environment(onboardingPermissionsModel)
                .environment(priceAlertNotificationNavigationInbox)
                .preferredColorScheme(.dark)
        }
    }
}

private enum PersistencePhase {
    case ready(ModelContainer)
    case failed(String)
}

@MainActor
private enum KARAApplicationPersistence {
    private static var modelContainer: ModelContainer?

    static func load() -> PersistencePhase {
        if let modelContainer {
            PriceAlertBestEffortBackgroundRefresh.install(
                modelContainer: modelContainer
            )
            return .ready(modelContainer)
        }

        do {
            let container = try KaraModelContainerFactory.make()
            modelContainer = container
            PriceAlertBestEffortBackgroundRefresh.install(
                modelContainer: container
            )
            return .ready(container)
        } catch {
            return .failed(String(describing: error))
        }
    }
}

private struct PersistenceHostView: View {
    @State private var phase: PersistencePhase

    init(initialPhase: PersistencePhase) {
        _phase = State(initialValue: initialPhase)
    }

    var body: some View {
        switch phase {
        case let .ready(container):
            ContentView()
                .modelContainer(container)
        case let .failed(message):
            PersistenceUnavailableView(message: message) {
                phase = KARAApplicationPersistence.load()
            }
        }
    }
}

private struct PersistenceUnavailableView: View {
    @Environment(KaraTheme.self) private var theme

    let message: String
    let retry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("persistence.error.title", systemImage: "icloud.slash")
                .foregroundStyle(theme.ink)
        } description: {
            VStack(spacing: KaraSpacing.small) {
                Text("persistence.error.body")
                Text(message)
                    .font(.caption)
                    .textSelection(.enabled)
            }
            .foregroundStyle(theme.muted)
        } actions: {
            Button("persistence.error.retry", action: retry)
                .buttonStyle(.glassProminent)
                .accessibilityIdentifier("persistence.retry")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.background.ignoresSafeArea())
    }
}
