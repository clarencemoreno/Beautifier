import Vision
import CoreImage

enum FaceSegmenter {
    /// Generates a hardware-accelerated AI segmentation mask using Apple's Neural Engine / Vision framework,
    /// where person/face pixels are white (1.0) and background pixels are black (0.0).
    ///
    /// - Parameter cgImage: The source image to segment.
    /// - Returns: A grayscale `CIImage` containing the segmentation mask, or fallback oval face mask if ANE is unavailable.
    static func segmentFace(in cgImage: CGImage) -> CIImage? {
        // 1. Hardware-accelerated Neural Engine Person Segmentation Request
        let request = VNGeneratePersonSegmentationRequest()
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8

        for quality in [VNGeneratePersonSegmentationRequest.QualityLevel.balanced, .accurate, .fast] {
            request.qualityLevel = quality
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            if (try? handler.perform([request])) != nil,
               let observation = request.results?.first {
                return CIImage(cvPixelBuffer: observation.pixelBuffer)
            }
        }

        // 2. Simulator Fallback: Generate smooth face oval mask from face detector bounding box
        if let geometry = FaceDetector.detectGeometry(in: cgImage) {
            let w = cgImage.width, h = cgImage.height
            guard let ctx = CGContext(data: nil, width: w, height: h,
                                      bitsPerComponent: 8, bytesPerRow: w,
                                      space: CGColorSpaceCreateDeviceGray(),
                                      bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }

            ctx.setFillColor(CGColor(gray: 0, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

            let box = geometry.faceBox
            let faceRect = CGRect(x: box.minX * CGFloat(w),
                                  y: box.minY * CGFloat(h),
                                  width: box.width * CGFloat(w),
                                  height: box.height * CGFloat(h))

            ctx.setFillColor(CGColor(gray: 1, alpha: 1))
            ctx.fillEllipse(in: faceRect)

            if let cgMask = ctx.makeImage() {
                return CIImage(cgImage: cgMask)
            }
        }

        return nil
    }
}
