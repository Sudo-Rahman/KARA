import PhotosUI
import SwiftUI
import UIKit

private enum ObjectPhotoModal: String, Identifiable {
    case camera

    var id: String { rawValue }
}

struct ObjectPhotoStepView: View {
    @Environment(KaraTheme.self) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let state: AssetCreationState
    let onContinue: () -> Void

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var presentedModal: ObjectPhotoModal?
    @State private var isPreparingPhoto = false

    var body: some View {
        AssetStepScaffold(
            title: "asset-flow.object.title",
            message: "asset-flow.object.body"
        ) {
            photoStage

            if let issue = state.issue, issue.kind == .objectAnalysis || issue.kind == .media {
                AssetIssueBanner(issue: issue, onDismiss: state.dismissIssue)
            }
        } footer: {
            footer
        }
        .fullScreenCover(item: $presentedModal) { modal in
            switch modal {
            case .camera:
                CameraCaptureView(
                    onCapture: prepareCapturedImage,
                    onCancel: { presentedModal = nil }
                )
                .ignoresSafeArea()
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task { await preparePhotoItem(item) }
        }
    }

    private var photoStage: some View {
        Group {
            if let data = state.objectPhotoData, let image = UIImage(data: data) {
                ZStack(alignment: .bottomLeading) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .aspectRatio(4 / 3, contentMode: .fit)
                        .clipped()

                    analysisBadge(state.objectAnalysisPhase)
                        .padding(KaraSpacing.medium)
                }
                .clipShape(.rect(cornerRadius: 16))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("asset-flow.object.preview.accessibility"))
                .accessibilityValue(analysisAccessibilityValue(state.objectAnalysisPhase))
                .accessibilityIdentifier("asset-flow.object.preview")
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(theme.surface)

                    RadialGradient(
                        colors: [theme.cobalt.opacity(0.20), .clear],
                        center: .center,
                        startRadius: 4,
                        endRadius: 150
                    )

                    VStack(spacing: KaraSpacing.medium) {
                        placeholderIcon

                        Text("asset-flow.object.placeholder.title")
                            .font(.headline)
                            .foregroundStyle(theme.ink)

                        Text("asset-flow.object.placeholder.body")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(theme.muted)
                            .frame(maxWidth: 280)
                    }
                    .padding(KaraSpacing.large)
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(dynamicTypeSize.isAccessibilitySize ? nil : 1.16, contentMode: .fit)
                .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 300 : nil)
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(theme.cobalt.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [7]))
                }
                .accessibilityIdentifier("asset-flow.object.placeholder")
            }
        }
    }

    @ViewBuilder
    private var placeholderIcon: some View {
        let icon = Image(systemName: "viewfinder")
            .font(.system(size: 46, weight: .light))
            .foregroundStyle(theme.goldBright)
            .accessibilityHidden(true)

        if reduceMotion {
            icon
        } else {
            icon.symbolEffect(.pulse, options: .repeating.speed(0.35))
        }
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: KaraSpacing.small) {
            if state.objectPhotoData == nil {
                Button {
                    presentCamera()
                } label: {
                    Group {
                        if isPreparingPhoto {
                            ProgressView()
                        } else {
                            Label("asset-flow.object.camera", systemImage: "camera.fill")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.karaPrimaryAction(isLoading: isPreparingPhoto))
                .disabled(isPreparingPhoto)
                .accessibilityIdentifier("asset-flow.object.camera")
            } else {
                Button(action: onContinue) {
                    Label("asset-flow.object.continue", systemImage: "arrow.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.karaPrimaryAction)
                .accessibilityIdentifier("asset-flow.object.continue")
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: KaraSpacing.small) {
                    alternatePhotoActions
                }

                VStack(spacing: KaraSpacing.small) {
                    alternatePhotoActions
                }
            }

            if state.objectPhotoData == nil {
                Button("asset-flow.object.skip", action: onContinue)
                    .buttonStyle(.plain)
                    .foregroundStyle(theme.muted)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("asset-flow.object.skip")
            }
        }
    }

    @ViewBuilder
    private var alternatePhotoActions: some View {
        if state.objectPhotoData != nil {
            Button {
                presentCamera()
            } label: {
                Label("asset-flow.object.retake", systemImage: "camera.rotate")
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.glass)
            .accessibilityIdentifier("asset-flow.object.retake")
        }

        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            Label("asset-flow.object.library", systemImage: "photo.on.rectangle")
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.glass)
        .disabled(isPreparingPhoto)
        .accessibilityIdentifier("asset-flow.object.library")
    }

    private func analysisBadge(_ phase: AssetAnalysisPhase) -> some View {
        HStack(spacing: KaraSpacing.small) {
            switch phase {
            case .idle:
                Image(systemName: "photo")
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
        .font(.caption.weight(.semibold))
        .foregroundStyle(theme.ink)
        .padding(.horizontal, KaraSpacing.medium)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
        .accessibilityIdentifier("asset-flow.object.analysis")
    }

    private func analysisAccessibilityValue(_ phase: AssetAnalysisPhase) -> Text {
        switch phase {
        case .idle: Text("asset-flow.analysis.ready")
        case .analyzing: Text("asset-flow.analysis.in-progress")
        case .completed: Text("asset-flow.analysis.completed")
        case .unavailable: Text("asset-flow.analysis.manual")
        }
    }

    private func presentCamera() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            state.reportMediaFailure()
            return
        }
        presentedModal = .camera
    }

    private func prepareCapturedImage(_ image: UIImage) {
        presentedModal = nil
        isPreparingPhoto = true
        let sendableImage = SendableObjectImage(image: image)

        Task {
            defer { isPreparingPhoto = false }
            do {
                let data = try await Task.detached(priority: .userInitiated) {
                    try MediaDocumentFactory.normalizedObjectJPEG(from: sendableImage.image)
                }.value
                state.setObjectPhoto(data)
            } catch is CancellationError {
                return
            } catch {
                state.reportMediaFailure()
            }
        }
    }

    private func preparePhotoItem(_ item: PhotosPickerItem) async {
        isPreparingPhoto = true
        defer {
            isPreparingPhoto = false
            selectedPhoto = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                state.reportMediaFailure()
                return
            }
            let normalized = try await Task.detached(priority: .userInitiated) {
                try MediaDocumentFactory.normalizedObjectJPEG(from: data)
            }.value
            state.setObjectPhoto(normalized)
        } catch is CancellationError {
            return
        } catch {
            state.reportMediaFailure()
        }
    }
}

private struct SendableObjectImage: @unchecked Sendable {
    let image: UIImage
}
