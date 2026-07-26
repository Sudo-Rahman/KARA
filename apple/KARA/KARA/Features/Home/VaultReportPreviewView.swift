import Foundation
import QuickLook
import SwiftUI

struct VaultReportPreviewView: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.locale) private var locale

    let assets: [Asset]
    let attachments: [AssetAttachment]
    let portfolioValuation: PortfolioValuation
    let valuationAsOf: Date

    @State private var state: VaultReportPreviewState = .loading
    @State private var generationAttempt = 0
    @State private var reportShareItem: VaultReportShareItem?
    @State private var isPreviewVisible = false

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.background.ignoresSafeArea())
            .navigationTitle("settings.vault.report.preview.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .tabBar)
            .toolbar {
                if let reportItem {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            reportShareItem = reportItem
                        } label: {
                            Label(
                                "settings.vault.report.preview.share",
                                systemImage: "square.and.arrow.up"
                            )
                        }
                        .accessibilityIdentifier("settings.vault.report.preview.share")
                    }
                }
            }
            .sheet(item: $reportShareItem, onDismiss: shareDidDismiss) { item in
                VaultReportActivityView(url: item.url)
                    .accessibilityIdentifier("settings.vault.report.share-sheet")
            }
            .task(id: generationAttempt) {
                await generateReport()
            }
            .onAppear {
                isPreviewVisible = true
            }
            .onDisappear {
                isPreviewVisible = false
                if reportShareItem == nil {
                    removeRenderedReport()
                }
            }
            .accessibilityIdentifier("settings.vault.report.preview")
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            VStack(spacing: KaraSpacing.medium) {
                ProgressView()
                    .controlSize(.large)
                    .tint(theme.goldBright)
                Text("settings.vault.report.generating")
                    .font(.headline)
                    .foregroundStyle(theme.ink)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("settings.vault.report.preview.loading")
        case let .ready(item):
            VaultReportQuickLookView(url: item.url)
                .ignoresSafeArea(.container, edges: .bottom)
                .accessibilityIdentifier("settings.vault.report.preview.document")
        case .failed:
            ContentUnavailableView {
                Label(
                    "settings.vault.report.error.title",
                    systemImage: "exclamationmark.triangle"
                )
            } description: {
                Text("settings.vault.report.error.body")
            } actions: {
                Button("settings.vault.report.error.retry") {
                    generationAttempt += 1
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.cobaltBright)
                .accessibilityIdentifier("settings.vault.report.preview.retry")
            }
            .foregroundStyle(theme.ink)
            .accessibilityIdentifier("settings.vault.report.preview.error")
        }
    }

    private var reportItem: VaultReportShareItem? {
        guard case let .ready(item) = state else { return nil }
        return item
    }

    @MainActor
    private func generateReport() async {
        removeRenderedReport()
        state = .loading

        await Task.yield()
        guard !Task.isCancelled else { return }

        let generatedAt = Date.now
        let reportLocale = locale
        var calendar = Calendar.current
        calendar.locale = reportLocale
        let snapshot: VaultReportSnapshot
        do {
            snapshot = try await VaultReportSnapshotAssembler.makeCooperatively(
                assets: assets,
                attachments: attachments,
                valuation: portfolioValuation,
                valuationAsOf: valuationAsOf
            )
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            state = .failed
            return
        }

        let renderer = VaultReportPDFRenderer(
            snapshot: snapshot,
            locale: reportLocale,
            generatedAt: generatedAt
        )
        let renderTask = Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let data = try renderer.render()
            try Task.checkCancellation()
            let transfer = VaultReportTransfer(
                data: data,
                generatedAt: generatedAt,
                calendar: calendar
            )
            let item = try TemporaryVaultReportFileStore.write(transfer: transfer)

            do {
                try Task.checkCancellation()
                return item
            } catch {
                TemporaryVaultReportFileStore.remove(item)
                throw error
            }
        }

        do {
            let item = try await withTaskCancellationHandler {
                try await renderTask.value
            } onCancel: {
                renderTask.cancel()
            }

            do {
                try Task.checkCancellation()
            } catch {
                TemporaryVaultReportFileStore.remove(item)
                throw error
            }

            state = .ready(item)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            state = .failed
        }
    }

    private func removeRenderedReport() {
        guard case let .ready(item) = state else { return }
        TemporaryVaultReportFileStore.remove(item)
    }

    private func shareDidDismiss() {
        if !isPreviewVisible {
            removeRenderedReport()
        }
    }
}

private enum VaultReportPreviewState {
    case loading
    case ready(VaultReportShareItem)
    case failed
}

private struct VaultReportQuickLookView: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(
        _ controller: QLPreviewController,
        context: Context
    ) {
        guard context.coordinator.url != url else { return }
        context.coordinator.url = url
        controller.reloadData()
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in _: QLPreviewController) -> Int { 1 }

        func previewController(
            _: QLPreviewController,
            previewItemAt _: Int
        ) -> any QLPreviewItem {
            url as NSURL
        }
    }
}
