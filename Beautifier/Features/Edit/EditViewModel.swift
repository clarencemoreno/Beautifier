import SwiftUI
import Combine
import CoreImage

@MainActor
final class EditViewModel: ObservableObject {
    @Published var previewImage: UIImage?
    @Published var amount: Float = 0.5
    @Published var showingOriginal = false
    @Published var isSaving = false
    @Published var alert: AlertState?

    @Published var faceGeometry: FaceGeometry?
    @Published var noFaceDetected = false
    @Published var showMaskDebug = false
    @Published var isDetectingFace = true

    private let originalData: Data
    private var previewCI: CIImage?
    private var previewMask: CIImage?
    private var renderTask: Task<Void, Never>?

    init(originalData: Data) {
        self.originalData = originalData
        load()
    }

    func load() {
        do {
            previewCI = try ImageLoader.downsampledPreviewCIImage(from: originalData, maxDimension: 2048)
            renderPreview()
            
            let normalizedImage = try ImageLoader.normalizedImage(from: originalData)
            
            Task.detached(priority: .userInitiated) {
                let geometry: FaceGeometry?
                if let cgImage = normalizedImage.cgImage {
                    geometry = FaceDetector.detectGeometry(in: cgImage)
                } else {
                    geometry = nil
                }

                await MainActor.run {
                    self.faceGeometry = geometry
                    self.noFaceDetected = (geometry == nil)
                    self.isDetectingFace = false
                    if let previewCI = self.previewCI, let geometry = geometry {
                        self.previewMask = SkinMaskBuilder.buildMask(for: previewCI, geometry: geometry)
                    } else {
                        self.previewMask = nil
                    }
                    self.renderPreview()
                }
            }
        } catch {
            isDetectingFace = false
            alert = AlertState(title: "Error", message: error.localizedDescription)
        }
    }

    func renderPreview() {
        renderTask?.cancel()
        renderTask = Task {
            await performRender()
        }
    }

    private func performRender() async {
        guard let previewCI, !Task.isCancelled else { return }
        
        let output: CIImage?
        if showMaskDebug {
            output = previewMask ?? CIImage(color: .black).cropped(to: previewCI.extent)
        } else if showingOriginal || amount <= 0 {
            output = previewCI
        } else if let faceGeometry, let previewMask {
            let radius = min(max(faceGeometry.faceBox.width * previewCI.extent.width * 0.04, 4), 15)
            output = SkinSmoothing.apply(to: previewCI, mask: previewMask, radius: radius, amount: amount)
        } else {
            // If face is not detected or detection is pending, apply global fallback smoothing
            output = SmoothingFilter.apply(to: previewCI, radius: 8, amount: amount)
        }

        guard let output, !Task.isCancelled else { return }
        guard let cgImage = RenderContext.shared.createCGImage(output, from: output.extent) else { return }
        previewImage = UIImage(cgImage: cgImage)
    }

    func save() async {
        isSaving = true
        defer {
            Task { @MainActor in isSaving = false }
        }

        do {
            let normalizedImage = try ImageLoader.normalizedImage(from: originalData)
            guard let ciImage = CIImage(image: normalizedImage) else { return }
            
            let output: CIImage
            if let faceGeometry {
                let fullMask = SkinMaskBuilder.buildMask(for: ciImage, geometry: faceGeometry)
                let radius = min(max(faceGeometry.faceBox.width * ciImage.extent.width * 0.04, 4), 15)
                output = SkinSmoothing.apply(to: ciImage, mask: fullMask, radius: radius, amount: amount)
            } else {
                output = SmoothingFilter.apply(to: ciImage, radius: 8, amount: amount)
            }

            let result = try ImageLoader.renderUIImage(from: output, scale: normalizedImage.scale)
            try await ImageSaver.save(result)
            alert = AlertState(title: "Saved", message: "Saved to Photos.")
        } catch {
            alert = AlertState(title: "Error", message: error.localizedDescription)
        }
    }
}

// MARK: - Alert State

enum AlertState {
    case alert(title: String, message: String)

    init(title: String, message: String) {
        self = .alert(title: title, message: message)
    }

    var title: String {
        switch self {
        case .alert(let title, _): return title
        }
    }

    var message: String {
        switch self {
        case .alert(_, let message): return message
        }
    }
}
