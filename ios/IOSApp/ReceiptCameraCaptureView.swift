#if canImport(UIKit)
import SwiftUI
import UIKit

struct ReceiptCameraCaptureView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onCapture: (Data) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        picker.cameraCaptureMode = .photo
        picker.modalPresentationStyle = .fullScreen
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: ReceiptCameraCaptureView

        init(parent: ReceiptCameraCaptureView) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            defer {
                picker.dismiss(animated: true)
                DispatchQueue.main.async {
                    self.parent.isPresented = false
                }
            }

            guard let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage) else {
                DispatchQueue.main.async {
                    self.parent.onCancel()
                }
                return
            }

            guard let data = image.jpegData(compressionQuality: 0.95) else {
                DispatchQueue.main.async {
                    self.parent.onCancel()
                }
                return
            }

            DispatchQueue.main.async {
                self.parent.onCapture(data)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            DispatchQueue.main.async {
                self.parent.isPresented = false
                self.parent.onCancel()
            }
        }
    }
}
#endif
