import CoreGraphics
import Vision

struct FaceGeometry {
    let faceBox: CGRect          // normalized, enlarged, bottom-left origin
    let exclusions: [CGRect]     // normalized rects in IMAGE coordinates: eyes, brows, lips
}

enum FaceGeometryBuilder {
    static func build(from observation: VNFaceObservation) -> FaceGeometry? {
        let originalBox = observation.boundingBox

        var box = originalBox
        box.origin.x -= box.width * 0.15      // wider
        box.origin.y -= box.height * 0.10     // less below chin
        box.size.width *= 1.30
        box.size.height *= 1.40               // extra upward = forehead
        box = box.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))

        let exclusions: [CGRect]
        if let lm = observation.landmarks {
            let regions = [lm.leftEye, lm.rightEye, lm.leftEyebrow,
                           lm.rightEyebrow, lm.outerLips]

            exclusions = regions.compactMap { region -> CGRect? in
                guard let region else { return nil }
                let imagePoints = region.normalizedPoints.map { facePoint in
                    CGPoint(
                        x: originalBox.origin.x + facePoint.x * originalBox.width,
                        y: originalBox.origin.y + facePoint.y * originalBox.height
                    )
                }
                let r = boundingRect(of: imagePoints)
                return r.insetBy(dx: -r.width * 0.2, dy: -r.height * 0.2)
            }
        } else {
            exclusions = []
        }

        return FaceGeometry(faceBox: box, exclusions: exclusions)
    }

    private static func boundingRect(of points: [CGPoint]) -> CGRect {
        guard let minX = points.map(\.x).min(),
              let maxX = points.map(\.x).max(),
              let minY = points.map(\.y).min(),
              let maxY = points.map(\.y).max() else { return .zero }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
