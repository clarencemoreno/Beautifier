import Vision
import CoreGraphics
import UIKit

enum FaceDetector {
    static func detectGeometry(in cgImage: CGImage, orientation: CGImagePropertyOrientation = .up) -> FaceGeometry? {
        let request = VNDetectFaceLandmarksRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        try? handler.perform([request])
        // pick the LARGEST face by bounding-box area
        guard let best = request.results?
            .max(by: { area($0) < area($1) }) else { return nil }
        return FaceGeometryBuilder.build(from: best)
    }

    private static func area(_ f: VNFaceObservation) -> CGFloat {
        f.boundingBox.width * f.boundingBox.height
    }
}
