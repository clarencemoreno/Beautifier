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

            if let previewCG = RenderContext.shared.createCGImage(previewCI, from: previewCI.extent) {
                previewImage = UIImage(cgImage: previewCG)
                isDetectingFace = true

                Task.detached(priority: .userInitiated) {
                    guard let previewCG = RenderContext.shared.createCGImage(previewCI, from: previewCI.extent) else {
                        await MainActor.run { self.handleNoFace() }
                        return
                    }

                    let geometry = FaceDetector.detectGeometry(in: previewCG)
                    let aiMask = (geometry != nil) ? SkinParserML.skinMask(for: previewCG) : nil
                    let mask = aiMask.map { SkinMaskBuilder.buildMask(for: previewCI, skinMask: $0) }
                    await MainActor.run {
                        self.faceGeometry = geometry
                        self.previewMask = mask
                        self.noFaceDetected = (geometry == nil || mask == nil)
                        self.isDetectingFace = false
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

    private func handleNoFace() {
        self.faceGeometry = nil
        self.previewMask = nil
        self.noFaceDetected = true
        self.isDetectingFace = false
        self.renderPreview()
    }

    func renderPreview() {
        renderTask?.cancel()
        renderTask = Task { await performRender() }
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
        } else if let previewMask {
            let scale = previewCI.extent.width / 2048.0
            let faceWidthRatio = faceGeometry?.faceBox.width ?? 0.5
            let baseRadius = max(6.0 * scale, faceWidthRatio * previewCI.extent.width * 0.05)
            let radius = min(baseRadius, 15.0 * scale)
            output = SkinSmoothing.apply(to: previewCI, mask: previewMask, radius: radius, amount: amount)
        } else {
            output = SmoothingFilter.apply(to: previewCI, radius: 15, amount: amount)
        }

        guard let output, !Task.isCancelled else { return }
        guard let cgImage = RenderContext.shared.createCGImage(output, from: output.extent) else { return }
        previewImage = UIImage(cgImage: cgImage)
    }

    func save() async {
        isSaving = true
        defer { Task { @MainActor in isSaving = false } }

        let currentAmount = self.amount
        let currentMask = self.previewMask
        let currentGeometry = self.faceGeometry
        let originalData = self.originalData

        // Move heavy full-res decoding and rendering off Main Thread
        let resultImage: UIImage? = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            do {
                let normalizedImage = try ImageLoader.normalizedImage(from: originalData)
                guard let ciImage = CIImage(image: normalizedImage) else { return nil }

                let output: CIImage
                if let previewMask = currentMask {
                    // Reuse existing preview mask, scaled up to full-resolution extent
                    let scaleX = ciImage.extent.width / previewMask.extent.width
                    let scaleY = ciImage.extent.height / previewMask.extent.height
                    let fullMask = previewMask.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

                    let scale = ciImage.extent.width / 2048.0
                    let faceWidthRatio = currentGeometry?.faceBox.width ?? 0.5
                    let baseRadius = max(6.0 * scale, faceWidthRatio * ciImage.extent.width * 0.05)
                    let radius = min(baseRadius, 15.0 * scale)
                    output = SkinSmoothing.apply(to: ciImage, mask: fullMask, radius: radius, amount: currentAmount)
                } else {
                    output = SmoothingFilter.apply(to: ciImage, radius: 15, amount: currentAmount)
                }

                return try? ImageLoader.renderUIImage(from: output, scale: normalizedImage.scale)
            } catch {
                return nil
            }
        }.value

        if let resultImage {
            do {
                try await ImageSaver.save(resultImage)
                alert = AlertState(title: "Saved", message: "Saved to Photos.")
            } catch {
                alert = AlertState(title: "Error", message: error.localizedDescription)
            }
        } else {
            alert = AlertState(title: "Error", message: "Failed to process image.")
        }
    }
}

struct AlertState: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}
