import SwiftUI

struct AssetDeletionRequest: Identifiable, Equatable {
    let id: UUID
    let name: String
}

private struct AssetDeletionPresentationModifier: ViewModifier {
    @Binding var request: AssetDeletionRequest?
    @Binding var isPresentingConfirmation: Bool
    @Binding var isShowingError: Bool

    let delete: @MainActor (UUID) throws -> Void
    let onDeleted: @MainActor () -> Void

    func body(content: Content) -> some View {
        content
            .alert(
                confirmationTitle,
                isPresented: $isPresentingConfirmation
            ) {
                Button("asset-delete.action.delete", role: .destructive) {
                    if let request = self.request {
                        performDeletion(request)
                    }
                }

                Button("asset-delete.action.cancel", role: .cancel) {
                    request = nil
                }
            } message: {
                Text("asset-delete.confirmation.message")
            }
            .alert(
                "asset-delete.error.title",
                isPresented: $isShowingError
            ) {
                Button("asset-delete.error.dismiss", role: .cancel) {}
            } message: {
                Text("asset-delete.error.message")
            }
    }

    private var confirmationTitle: Text {
        guard let request else {
            return Text("asset-delete.confirmation.fallback-title")
        }
        return Text("asset-delete.confirmation.title \(request.name)")
    }

    private func performDeletion(_ request: AssetDeletionRequest) {
        do {
            try delete(request.id)
            self.request = nil
            isPresentingConfirmation = false
            onDeleted()
        } catch {
            self.request = nil
            isPresentingConfirmation = false
            isShowingError = true
        }
    }
}

extension View {
    func assetDeletionPresentation(
        request: Binding<AssetDeletionRequest?>,
        isPresentingConfirmation: Binding<Bool>,
        isShowingError: Binding<Bool>,
        delete: @escaping @MainActor (UUID) throws -> Void,
        onDeleted: @escaping @MainActor () -> Void = {}
    ) -> some View {
        modifier(AssetDeletionPresentationModifier(
            request: request,
            isPresentingConfirmation: isPresentingConfirmation,
            isShowingError: isShowingError,
            delete: delete,
            onDeleted: onDeleted
        ))
    }
}
