import CoreImage
import CoreVideo
import Vision
import Foundation

final class LiveProcessor {
    private let inferenceQueue = DispatchQueue(label: "com.beautifier.inference", qos: .userInitiated)
    private let stateLock = NSLock()

    private var isInferring: Bool = false
    private var cachedMask: CIImage?
    private var cachedFaceGeometry: FaceGeometry?
    private var lastFaceBox: CGRect?

    func process(image: CIImage, amount: Float) -> CIImage {
        guard amount > 0 else { return image }

        // Trigger async inference if worker is idle
        triggerAsyncInferenceIfNeeded(for: image)

        // Read current cached state atomically
        stateLock.lock()
        let activeMask = cachedMask
        let activeGeometry = cachedFaceGeometry
        stateLock.unlock()

        guard let activeMask else {
            // Warm-up or no face detected: return raw frame without blur
            return image
        }

        // Bounded radius formula (D4)
        let frameWidth = image.extent.width
        let scale = frameWidth / 2048.0
        let faceWidthRatio = activeGeometry?.faceBox.width ?? 0.5
        let baseRadius = max(6.0 * scale, faceWidthRatio * frameWidth * 0.05)
        let radius = min(baseRadius, 15.0 * scale)

        return SkinSmoothing.apply(to: image, mask: activeMask, radius: radius, amount: amount)
    }

    private func triggerAsyncInferenceIfNeeded(for image: CIImage) {
        stateLock.lock()
        if isInferring {
            stateLock.unlock()
            return
        }
        isInferring = true
        stateLock.unlock()

        // Capture frame snapshot for background inference
        let frameExtent = image.extent
        inferenceQueue.async { [weak self] in
            guard let self else { return }
            defer {
                self.stateLock.lock()
                self.isInferring = false
                self.stateLock.unlock()
            }

            guard let cgImage = RenderContext.shared.createCGImage(image, from: frameExtent) else {
                self.invalidateCache()
                return
            }

            // 1. Detect face geometry
            guard let geometry = FaceDetector.detectGeometry(in: cgImage) else {
                self.invalidateCache()
                return
            }

            // 2. Check bounding box shift for cache invalidation (D3)
            let newBox = geometry.faceBox
            self.stateLock.lock()
            if let oldBox = self.lastFaceBox {
                let dx = abs(newBox.midX - oldBox.midX)
                let dy = abs(newBox.midY - oldBox.midY)
                let dArea = abs((newBox.width * newBox.height) - (oldBox.width * oldBox.height)) / (oldBox.width * oldBox.height)
                if dx > 0.15 || dy > 0.15 || dArea > 0.20 {
                    // Significant movement: temporarily invalidate mask while updating
                    self.cachedMask = nil
                }
            }
            self.lastFaceBox = newBox
            self.stateLock.unlock()

            // 3. Run semantic skin parsing via Core ML
            guard let aiMask = SkinParserML.skinMask(for: cgImage) else {
                self.invalidateCache()
                return
            }

            let fullMask = SkinMaskBuilder.buildMask(for: image, skinMask: aiMask)

            self.stateLock.lock()
            self.cachedMask = fullMask
            self.cachedFaceGeometry = geometry
            self.stateLock.unlock()
        }
    }

    func invalidateCache() {
        stateLock.lock()
        cachedMask = nil
        cachedFaceGeometry = nil
        lastFaceBox = nil
        stateLock.unlock()
    }
}
