import Vision
import CoreGraphics
import UIKit

enum FaceDetector {
    static func detectGeometry(in cgImage: CGImage, orientation: CGImagePropertyOrientation = .up) -> FaceGeometry? {
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])

        let landmarksRequest = VNDetectFaceLandmarksRequest()
        try? handler.perform([landmarksRequest])

        if let best = landmarksRequest.results?.max(by: { area($0) < area($1) }),
           let geometry = FaceGeometryBuilder.build(from: best) {
            return geometry
        }

        let rectsRequest = VNDetectFaceRectanglesRequest()
        try? handler.perform([rectsRequest])

        if let bestRect = rectsRequest.results?.max(by: { area($0) < area($1) }),
           let geometry = FaceGeometryBuilder.build(from: bestRect) {
            return geometry
        }

        return nil
    }

    private static func area(_ f: VNFaceObservation) -> CGFloat {
        f.boundingBox.width * f.boundingBox.height
    }
}
