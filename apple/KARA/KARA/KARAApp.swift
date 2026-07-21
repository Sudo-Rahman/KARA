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

    var body: some Scene {
        WindowGroup {
            PersistenceHostView()
                .environment(flow)
                .environment(theme)
                .environment(privacyPreferences)
                .preferredColorScheme(.dark)
        }
    }
}

private struct PersistenceHostView: View {
    private enum Phase {
        case ready(ModelContainer)
        case failed(String)
    }

    @State private var phase = Self.loadContainer()

    var body: some View {
        switch phase {
        case let .ready(container):
            ContentView()
                .modelContainer(container)
        case let .failed(message):
            PersistenceUnavailableView(message: message) {
                phase = Self.loadContainer()
            }
        }
    }

    private static func loadContainer() -> Phase {
        do {
            return .ready(try KaraModelContainerFactory.make())
        } catch {
            return .failed(String(describing: error))
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
