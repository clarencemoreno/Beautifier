//
//  CameraView.swift
//  Beautifier
//
//  Created by ClyCesBon on 8/1/26.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct CameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    let onError: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        
        // Check if camera is available (e.g., not in Simulator)
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
        } else {
            // Simulator fallback: use photo library instead
            picker.sourceType = .photoLibrary
            picker.mediaTypes = [UTType.image.identifier]
        }
        
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                // Resize to a reasonable size for processing
                let resized = image.resized(to: CGSize(width: 1024, height: 1024))
                parent.onCapture(resized)
            } else {
                parent.onError("Failed to capture image.")
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - UIImage resizing helper

extension UIImage {
    /// Resizes an image to the specified size while maintaining aspect ratio.
    func resized(to targetSize: CGSize) -> UIImage {
        let size = self.size
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio)

        let newWidth  = CGFloat(Int(size.width  * ratio))
        let newHeight = CGFloat(Int(size.height * ratio))

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: newWidth, height: newHeight))
        return renderer.image { _ in
            self.draw(in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        }
    }
}
