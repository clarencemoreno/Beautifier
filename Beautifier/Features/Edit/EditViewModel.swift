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
    private var faceSegmentationMask: CIImage?
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
                        await MainActor.run {
                            self.faceGeometry = nil
                            self.faceSegmentationMask = nil
                            self.previewMask = nil
                            self.noFaceDetected = true
                            self.isDetectingFace = false
                            self.renderPreview()
                        }
                        return
                    }

                    if FeatureFlags.semanticSkinParser {
                        // ——— New pipeline: BiSeNet semantic skin parser (runs in background) ———
                        let geometry = FaceDetector.detectGeometry(in: previewCG)
                        let aiMask = (geometry != nil) ? SkinParserML.skinMask(for: previewCG) : nil
                        let mask = aiMask.map { SkinMaskBuilder.buildMask(for: previewCI, skinMask: $0) }

                        await MainActor.run {
                            self.faceGeometry = geometry
                            self.previewMask = mask
                            self.noFaceDetected = (geometry == nil)
                            self.isDetectingFace = false
                            self.renderPreview()
                        }
                    } else {
                        // ——— Legacy pipeline: person segmentation + ellipse fallback ———
                        let geometry = FaceDetector.detectGeometry(in: previewCG)
                        let aiMask = FaceSegmenter.segmentFace(in: previewCG)
                        let mask: CIImage?
                        if let geometry, let aiMask {
                            mask = SkinMaskBuilder.buildMask(for: previewCI, geometry: geometry, faceMask: aiMask)
                        } else {
                            mask = nil
                        }

                        await MainActor.run {
                            self.faceGeometry = geometry
                            self.faceSegmentationMask = aiMask
                            self.previewMask = mask
                            self.noFaceDetected = (geometry == nil)
                            self.isDetectingFace = false
                            self.renderPreview()
                        }
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
        } else if FeatureFlags.semanticSkinParser, let previewMask {
            // Semantic skin parser pipeline: smooth skin area with scaled radius
            let scale = previewCI.extent.width / 2048.0
            let faceWidthRatio = faceGeometry?.faceBox.width ?? 0.5
            let baseRadius = max(8.0, faceWidthRatio * previewCI.extent.width * 0.05)
            let radius = min(max(baseRadius, 6.0 * scale), 24.0 * scale)
            output = SkinSmoothing.apply(to: previewCI, mask: previewMask, radius: radius, amount: amount)
        } else if let faceGeometry, let previewMask {
            // Legacy pipeline: needs faceGeometry for radius sizing
            let baseRadius = max(12.0, faceGeometry.faceBox.width * previewCI.extent.width * 0.08)
            output = SkinSmoothing.apply(to: previewCI, mask: previewMask, radius: baseRadius, amount: amount)
        } else {
            output = SmoothingFilter.apply(to: previewCI, radius: 24, amount: amount)
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
            if FeatureFlags.semanticSkinParser {
                // New pipeline: BiSeNet semantic skin parser at full resolution
                guard let fullCG = normalizedImage.cgImage,
                      let faceGeometry = FaceDetector.detectGeometry(in: fullCG),
                      let aiMask = SkinParserML.skinMask(for: fullCG) else {
                    output = SmoothingFilter.apply(to: ciImage, radius: 24, amount: amount)
                    let result = try ImageLoader.renderUIImage(from: output, scale: normalizedImage.scale)
                    try await ImageSaver.save(result)
                    alert = AlertState(title: "Saved", message: "Saved to Photos.")
                    return
                }
                let fullMask = SkinMaskBuilder.buildMask(for: ciImage, skinMask: aiMask)
                let scale = ciImage.extent.width / 2048.0
                let faceWidthRatio = faceGeometry.faceBox.width
                let baseRadius = max(8.0, faceWidthRatio * ciImage.extent.width * 0.05)
                let radius = min(max(baseRadius, 6.0 * scale), 24.0 * scale)
                output = SkinSmoothing.apply(to: ciImage, mask: fullMask, radius: radius, amount: amount)
            } else {
                // Legacy pipeline: person segmentation + ellipse fallback
                guard let faceGeometry = faceGeometry,
                      let cgImage = normalizedImage.cgImage,
                      let aiMask = FaceSegmenter.segmentFace(in: cgImage) else {
                    output = SmoothingFilter.apply(to: ciImage, radius: 24, amount: amount)
                    let result = try ImageLoader.renderUIImage(from: output, scale: normalizedImage.scale)
                    try await ImageSaver.save(result)
                    alert = AlertState(title: "Saved", message: "Saved to Photos.")
                    return
                }
                let fullMask = SkinMaskBuilder.buildMask(for: ciImage, geometry: faceGeometry, faceMask: aiMask)
                let baseRadius = max(12.0, faceGeometry.faceBox.width * ciImage.extent.width * 0.08)
                output = SkinSmoothing.apply(to: ciImage, mask: fullMask, radius: baseRadius, amount: amount)
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
