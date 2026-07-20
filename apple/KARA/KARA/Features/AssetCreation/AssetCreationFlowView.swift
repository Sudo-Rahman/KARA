import SwiftUI

struct AssetCreationFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(KaraTheme.self) private var theme

    @State private var state: AssetCreationState
    @State private var router = AssetCreationRouter()
    @State private var showsCancelConfirmation = false
    @State private var savedFeedback = 0

    init(state: AssetCreationState) {
        _state = State(initialValue: state)
    }

    var body: some View {
        @Bindable var router = router

        NavigationStack(path: $router.path) {
            ObjectPhotoStepView(
                state: state,
                onContinue: { router.advance(to: .invoice) }
            )
            .assetCreationCancelToolbar(action: requestCancellation)
            .navigationDestination(for: AssetCreationStep.self) { step in
                destination(for: step)
            }
        }
        .background(theme.background.ignoresSafeArea())
        .tint(theme.cobaltBright)
        .interactiveDismissDisabled()
        .sensoryFeedback(.selection, trigger: router.currentStep)
        .sensoryFeedback(.success, trigger: savedFeedback)
        .confirmationDialog(
            "asset-flow.cancel.confirmation.title",
            isPresented: $showsCancelConfirmation,
            titleVisibility: .visible
        ) {
            Button("asset-flow.cancel.confirmation.action", role: .destructive) {
                cancelAndDismiss()
            }
            Button("asset-flow.cancel.confirmation.keep", role: .cancel) {}
        } message: {
            Text("asset-flow.cancel.confirmation.body")
        }
        .onDisappear {
            state.cancelAllWork()
        }
    }

    @ViewBuilder
    private func destination(for step: AssetCreationStep) -> some View {
        switch step {
        case .objectPhoto:
            ObjectPhotoStepView(
                state: state,
                onContinue: { router.advance(to: .invoice) }
            )
            .assetCreationCancelToolbar(action: requestCancellation)
        case .invoice:
            InvoiceStepView(
                state: state,
                onContinue: { router.advance(to: .classification) }
            )
            .assetCreationCancelToolbar(action: requestCancellation)
        case .classification:
            AssetClassificationStepView(
                state: state,
                onContinue: { router.advance(to: .characteristics) }
            )
            .assetCreationCancelToolbar(action: requestCancellation)
        case .characteristics:
            AssetCharacteristicsStepView(
                state: state,
                onContinue: { router.advance(to: .purchase) }
            )
            .assetCreationCancelToolbar(action: requestCancellation)
        case .purchase:
            AssetPurchaseStepView(
                state: state,
                onContinue: { router.advance(to: .summary) }
            )
            .assetCreationCancelToolbar(action: requestCancellation)
        case .summary:
            AssetSummaryStepView(
                state: state,
                onEdit: router.editCharacteristics,
                onSaved: finishAfterSave
            )
            .assetCreationCancelToolbar(action: requestCancellation)
        }
    }

    private func requestCancellation() {
        if state.hasUserContent {
            showsCancelConfirmation = true
        } else {
            cancelAndDismiss()
        }
    }

    private func cancelAndDismiss() {
        state.cancelAllWork()
        dismiss()
    }

    private func finishAfterSave() {
        savedFeedback += 1
        dismiss()
    }
}

private extension View {
    func assetCreationCancelToolbar(action: @escaping () -> Void) -> some View {
        toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("asset-flow.cancel", systemImage: "xmark", action: action)
                    .labelStyle(.iconOnly)
                    .accessibilityIdentifier("asset-flow.cancel")
            }
        }
    }
}
