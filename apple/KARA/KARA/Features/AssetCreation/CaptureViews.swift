import SwiftUI
import UIKit
import VisionKit

@MainActor
struct CameraCaptureView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.delegate = context.coordinator
        controller.sourceType = .camera
        controller.cameraCaptureMode = .photo
        controller.allowsEditing = false
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIImagePickerController,
        context: Context
    ) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate,
        UINavigationControllerDelegate
    {
        private let parent: CameraCaptureView

        init(parent: CameraCaptureView) {
            self.parent = parent
        }

        func imagePickerController(
            _: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            guard let image = info[.originalImage] as? UIImage else {
                parent.onCancel()
                return
            }

            parent.onCapture(image)
        }

        func imagePickerControllerDidCancel(_: UIImagePickerController) {
            parent.onCancel()
        }
    }
}

@MainActor
struct DocumentScannerView: UIViewControllerRepresentable {
    let onScan: ([UIImage]) -> Void
    let onCancel: () -> Void
    let onFailure: (Error) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(
        _ uiViewController: VNDocumentCameraViewController,
        context: Context
    ) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private let parent: DocumentScannerView

        init(parent: DocumentScannerView) {
            self.parent = parent
        }

        func documentCameraViewController(
            _: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            let images = (0 ..< scan.pageCount).map(scan.imageOfPage(at:))
            parent.onScan(images)
        }

        func documentCameraViewControllerDidCancel(
            _: VNDocumentCameraViewController
        ) {
            parent.onCancel()
        }

        func documentCameraViewController(
            _: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            parent.onFailure(error)
        }
    }
}
