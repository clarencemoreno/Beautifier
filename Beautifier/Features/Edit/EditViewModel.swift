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
            let previewCI = try ImageLoader.downsampledPreviewCIImage(from: originalData, maxDimension: 2048)
            self.previewCI = previewCI

            // Generate guaranteed CGImage from previewCI to avoid UIImage(data:).cgImage returning nil
            if let previewCG = RenderContext.shared.createCGImage(previewCI, from: previewCI.extent) {
                previewImage = UIImage(cgImage: previewCG)

                Task.detached(priority: .userInitiated) {
                    let geometry = FaceDetector.detectGeometry(in: previewCG)

                    await MainActor.run {
                        self.faceGeometry = geometry
                        self.noFaceDetected = (geometry == nil)
                        self.isDetectingFace = false
                        if let geometry = geometry {
                            self.previewMask = SkinMaskBuilder.buildMask(for: previewCI, geometry: geometry)
                        } else {
                            self.previewMask = nil
                        }
                        self.renderPreview()
                    }
                }
            } else {
                isDetectingFace = false
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
        } else if isDetectingFace {
            output = previewCI
        } else if let faceGeometry, let previewMask {
            let radius = min(max(faceGeometry.faceBox.width * previewCI.extent.width * 0.04, 4), 15)
            output = SkinSmoothing.apply(to: previewCI, mask: previewMask, radius: radius, amount: amount)
        } else {
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

struct AlertState: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}
