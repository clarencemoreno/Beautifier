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

                Task.detached(priority: .userInitiated) {
                    let previewCG = RenderContext.shared.createCGImage(previewCI, from: previewCI.extent)

                    await MainActor.run {
                        self.faceGeometry = nil
                        self.faceSegmentationMask = nil
                        self.noFaceDetected = true
                        self.isDetectingFace = false

                        guard let previewCG else {
                            self.renderPreview()
                            return
                        }

                        if FeatureFlags.semanticSkinParser {
                            // ——— New pipeline: BiSeNet semantic skin parser ———
                            let aiMask = SkinParserML.skinMask(for: previewCG)
                            if let aiMask = aiMask {
                                self.noFaceDetected = (self._maskMeanLuminance(aiMask) < 0.01)
                                self.previewMask = SkinMaskBuilder.buildMask(for: previewCI, skinMask: aiMask)
                            } else {
                                self.noFaceDetected = true
                                self.previewMask = nil
                            }
                        } else {
                            // ——— Legacy pipeline: person segmentation + ellipse fallback ———
                            let geometry = FaceDetector.detectGeometry(in: previewCG)
                            let aiMask = FaceSegmenter.segmentFace(in: previewCG)

                            self.faceGeometry = geometry
                            self.faceSegmentationMask = aiMask
                            self.noFaceDetected = (geometry == nil)

                            if let geometry = geometry, let aiMask = aiMask {
                                self.previewMask = SkinMaskBuilder.buildMask(for: previewCI, geometry: geometry, faceMask: aiMask)
                            } else {
                                self.previewMask = nil
                            }
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
        } else if FeatureFlags.semanticSkinParser, let previewMask {
            // New pipeline: use previewMask directly (no faceGeometry needed)
            let maxRadius = 15.0 * previewCI.extent.width / 2048.0
            let radius = min(max(4.0 * previewCI.extent.width / 2048.0, 4.0), maxRadius)
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

    /// Returns the mean luminance of a mask CIImage (0 = no skin, ~1 = full skin).
    private func _maskMeanLuminance(_ mask: CIImage) -> Double {
        guard let cg = RenderContext.shared.createCGImage(mask, from: mask.extent) else { return 0 }
        let w = cg.width, h = cg.height
        guard let ctx = CGContext(data: nil, width: w, height: h,
                                   bitsPerComponent: 8, bytesPerRow: w * 4,
                                   space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = ctx.data else { return 0 }
        let ptr = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
        var total: Double = 0
        let pixelCount = w * h
        for i in 0..<pixelCount {
            let r = Double(ptr[i * 4])
            let g = Double(ptr[i * 4 + 1])
            let b = Double(ptr[i * 4 + 2])
            total += (r + g + b) / (3.0 * 255.0)
        }
        return total / Double(pixelCount)
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
                      let aiMask = SkinParserML.skinMask(for: fullCG) else {
                    output = SmoothingFilter.apply(to: ciImage, radius: 24, amount: amount)
                    let result = try ImageLoader.renderUIImage(from: output, scale: normalizedImage.scale)
                    try await ImageSaver.save(result)
                    alert = AlertState(title: "Saved", message: "Saved to Photos.")
                    return
                }
                let fullMask = SkinMaskBuilder.buildMask(for: ciImage, skinMask: aiMask)
                let maxRadius = 15.0 * ciImage.extent.width / 2048.0
                let radius = min(max(4.0 * ciImage.extent.width / 2048.0, 4.0), maxRadius)
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
