import SwiftUI
import UniformTypeIdentifiers
import VisionKit

private enum InvoiceModal: String, Identifiable {
    case scanner

    var id: String { rawValue }
}

struct InvoiceStepView: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let state: AssetCreationState
    let onContinue: () -> Void

    @State private var presentedModal: InvoiceModal?
    @State private var showsFileImporter = false
    @State private var isPreparingDocument = false

    var body: some View {
        AssetStepScaffold(
            title: "invoice.title",
            message: "invoice.body"
        ) {
            invoiceStage

            if let issue = state.issue, issue.kind == .invoiceAnalysis || issue.kind == .media {
                AssetIssueBanner(issue: issue, onDismiss: state.dismissIssue)
            }
        } footer: {
            footer
        }
        .fullScreenCover(item: $presentedModal) { modal in
            switch modal {
            case .scanner:
                DocumentScannerView(
                    onScan: prepareScan,
                    onCancel: { presentedModal = nil },
                    onFailure: { _ in
                        presentedModal = nil
                        state.reportMediaFailure()
                    }
                )
                .ignoresSafeArea()
            }
        }
        .fileImporter(
            isPresented: $showsFileImporter,
            allowedContentTypes: [.pdf, .image],
            allowsMultipleSelection: false,
            onCompletion: importDocument
        )
    }

    @ViewBuilder
    private var invoiceStage: some View {
        if let document = state.invoiceDocument {
            AssetFieldSurface {
                HStack(alignment: .top, spacing: KaraSpacing.medium) {
                    Image(systemName: "doc.richtext.fill")
                        .font(.title2)
                        .foregroundStyle(theme.goldBright)
                        .frame(width: 50, height: 50)
                        .background(theme.gold.opacity(0.13), in: .rect(cornerRadius: 12))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: KaraSpacing.xSmall) {
                        Text(document.filename)
                            .font(.headline)
                            .foregroundStyle(theme.ink)
                            .lineLimit(3)

                        Text("invoice.pages \(document.pageCount)")
                            .font(.subheadline)
                            .foregroundStyle(theme.muted)

                        InvoiceAnalysisStatus(phase: state.invoiceAnalysisPhase)
                            .padding(.top, KaraSpacing.xSmall)
                    }

                    Spacer(minLength: 0)

                    Button("invoice.remove", systemImage: "trash", role: .destructive) {
                        state.removeInvoiceDocument()
                    }
                    .labelStyle(.iconOnly)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityIdentifier("invoice.remove")
                }
            }
            .accessibilityIdentifier("invoice.document")
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.surface)

                LinearGradient(
                    colors: [theme.cobalt.opacity(0.12), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                VStack(spacing: KaraSpacing.medium) {
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 46, weight: .light))
                        .foregroundStyle(theme.goldBright)
                        .accessibilityHidden(true)

                    Text("invoice.placeholder.title")
                        .font(.headline)
                        .foregroundStyle(theme.ink)

                    Text("invoice.placeholder.body")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(theme.muted)
                        .frame(maxWidth: 290)
                }
                .padding(KaraSpacing.large)
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(dynamicTypeSize.isAccessibilitySize ? nil : 1.45, contentMode: .fit)
            .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 280 : nil)
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(theme.cobalt.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [7]))
            }
            .accessibilityIdentifier("invoice.placeholder")
        }
    }

    private var footer: some View {
        VStack(spacing: KaraSpacing.small) {
            if state.invoiceDocument == nil {
                Button {
                    presentScanner()
                } label: {
                    Group {
                        if isPreparingDocument {
                            ProgressView()
                        } else {
                            Label("invoice.scan", systemImage: "viewfinder")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.karaPrimaryAction(isLoading: isPreparingDocument))
                .disabled(isPreparingDocument)
                .accessibilityIdentifier("invoice.scan")
            } else {
                Button(action: onContinue) {
                    Label("invoice.continue", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.karaPrimaryAction)
                .accessibilityIdentifier("invoice.continue")
            }

            if state.invoiceDocument == nil {
                invoiceInputActions
            } else {
                invoiceReplacementActions
            }
        }
    }

    @ViewBuilder
    private var invoiceInputActions: some View {
        ViewThatFits(in: .horizontal) {
            GlassEffectContainer(spacing: KaraSpacing.small) {
                HStack(spacing: KaraSpacing.small) {
                    importButton
                    skipButton
                }
            }

            GlassEffectContainer(spacing: KaraSpacing.small) {
                HStack(spacing: KaraSpacing.small) {
                    importIconButton
                    skipIconButton
                }
            }
        }
    }

    @ViewBuilder
    private var invoiceReplacementActions: some View {
        ViewThatFits(in: .horizontal) {
            GlassEffectContainer(spacing: KaraSpacing.small) {
                HStack(spacing: KaraSpacing.small) {
                    rescanButton
                    importButton
                }
            }

            GlassEffectContainer(spacing: KaraSpacing.small) {
                HStack(spacing: KaraSpacing.small) {
                    rescanIconButton
                    importIconButton
                }
            }
        }
    }

    private var importButton: some View {
        Button {
            showsFileImporter = true
        } label: {
            Label("invoice.import", systemImage: "folder")
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.karaSecondaryAction)
        .disabled(isPreparingDocument)
        .accessibilityIdentifier("invoice.import")
    }

    private var importIconButton: some View {
        Button {
            showsFileImporter = true
        } label: {
            Image(systemName: "folder")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.karaSecondaryAction)
        .disabled(isPreparingDocument)
        .accessibilityLabel("invoice.import")
        .accessibilityIdentifier("invoice.import")
    }

    private var skipButton: some View {
        Button {
            onContinue()
        } label: {
            Label("invoice.skip", systemImage: "forward.end")
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.karaSecondaryAction)
        .accessibilityIdentifier("invoice.skip")
    }

    private var skipIconButton: some View {
        Button {
            onContinue()
        } label: {
            Image(systemName: "forward.end")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.karaSecondaryAction)
        .accessibilityLabel("invoice.skip")
        .accessibilityIdentifier("invoice.skip")
    }

    private var rescanButton: some View {
        Button {
            presentScanner()
        } label: {
            Label("invoice.scan", systemImage: "viewfinder")
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.karaSecondaryAction)
        .disabled(isPreparingDocument)
        .accessibilityIdentifier("invoice.scan")
    }

    private var rescanIconButton: some View {
        Button {
            presentScanner()
        } label: {
            Image(systemName: "viewfinder")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.karaSecondaryAction)
        .disabled(isPreparingDocument)
        .accessibilityLabel("invoice.scan")
        .accessibilityIdentifier("invoice.scan")
    }

    private func presentScanner() {
        guard VNDocumentCameraViewController.isSupported else {
            state.reportMediaFailure()
            return
        }
        presentedModal = .scanner
    }

    private func prepareScan(_ images: [UIImage]) {
        presentedModal = nil
        isPreparingDocument = true
        let sendableImages = images.map(SendableInvoiceImage.init)

        Task {
            defer { isPreparingDocument = false }
            do {
                let document = try await Task.detached(priority: .userInitiated) {
                    try MediaDocumentFactory.invoicePDF(from: sendableImages.map(\.image))
                }.value
                state.setInvoiceDocument(document)
            } catch is CancellationError {
                return
            } catch {
                state.reportMediaFailure()
            }
        }
    }

    private func importDocument(_ result: Result<[URL], Error>) {
        isPreparingDocument = true

        Task {
            defer { isPreparingDocument = false }
            do {
                guard let url = try result.get().first else { return }
                let document = try await Task.detached(priority: .userInitiated) {
                    let didAccess = url.startAccessingSecurityScopedResource()
                    defer {
                        if didAccess { url.stopAccessingSecurityScopedResource() }
                    }

                    let data = try Data(contentsOf: url, options: .mappedIfSafe)
                    let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType
                    let mimeType = type?.preferredMIMEType ?? "application/octet-stream"
                    return try MediaDocumentFactory.invoiceDocument(
                        fromImportedData: data,
                        filename: url.lastPathComponent,
                        mimeType: mimeType
                    )
                }.value
                state.setInvoiceDocument(document)
            } catch is CancellationError {
                return
            } catch {
                state.reportMediaFailure()
            }
        }
    }
}

private struct SendableInvoiceImage: @unchecked Sendable {
    let image: UIImage
}

private struct InvoiceAnalysisStatus: View {
    @Environment(KaraTheme.self) private var theme

    let phase: AssetAnalysisPhase

    var body: some View {
        HStack(spacing: KaraSpacing.small) {
            switch phase {
            case .idle:
                Image(systemName: "doc.text.magnifyingglass")
                Text("asset-flow.analysis.ready")
            case .analyzing:
                ProgressView()
                    .controlSize(.small)
                Text("asset-flow.analysis.in-progress")
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(theme.goldBright)
                Text("asset-flow.analysis.completed")
            case .unavailable:
                Image(systemName: "pencil.and.list.clipboard")
                Text("asset-flow.analysis.manual")
            }
        }
        .font(.subheadline)
        .foregroundStyle(theme.ink)
        .accessibilityIdentifier("invoice.analysis")
    }
}
