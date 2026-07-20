import Testing
import UIKit
@testable import KARA

@Suite("Capture presentation coordination")
@MainActor
struct CapturePresentationCoordinationTests {
    @Test("Camera cancellation delegates dismissal to the SwiftUI presentation")
    func cameraCancellationDoesNotDismissUIKitController() {
        var didCancel = false
        let view = CameraCaptureView(
            onCapture: { _ in },
            onCancel: { didCancel = true }
        )
        let picker = DismissSpyImagePickerController()

        view.makeCoordinator().imagePickerControllerDidCancel(picker)

        #expect(didCancel)
        #expect(picker.dismissCallCount == 0)
    }

    @Test("A captured photo delegates dismissal to the SwiftUI presentation")
    func cameraCaptureDoesNotDismissUIKitController() {
        let image = UIImage()
        var capturedImage: UIImage?
        let view = CameraCaptureView(
            onCapture: { capturedImage = $0 },
            onCancel: {}
        )
        let picker = DismissSpyImagePickerController()

        view.makeCoordinator().imagePickerController(
            picker,
            didFinishPickingMediaWithInfo: [.originalImage: image]
        )

        #expect(capturedImage === image)
        #expect(picker.dismissCallCount == 0)
    }
}

@MainActor
private final class DismissSpyImagePickerController: UIImagePickerController {
    private(set) var dismissCallCount = 0

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        dismissCallCount += 1
        completion?()
    }
}
