import XCTest
@testable import Beautifier

final class BeautifierPipelineTests: XCTestCase {

    func testFaceDetectionAndSkinMask() throws {
        // Create synthetic face image with pink circle on white background
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 500, height: 500))
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 500, height: 500))
            UIColor.systemPink.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 100, y: 100, width: 300, height: 300))
        }
        
        guard let data = image.jpegData(compressionQuality: 0.9),
              let previewCI = try? ImageLoader.downsampledPreviewCIImage(from: data) else {
            XCTFail("Failed to prepare test image data")
            return
        }

        // Dummy geometry test
        let faceBox = CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
        let geometry = FaceGeometry(faceBox: faceBox, exclusions: [])

        let mask = SkinMaskBuilder.buildMask(for: previewCI, geometry: geometry)
        XCTAssertNotNil(mask, "SkinMaskBuilder should generate mask")
        
        let output = SkinSmoothing.apply(to: previewCI, mask: mask, radius: 8, amount: 0.5)
        XCTAssertNotNil(output, "SkinSmoothing filter should produce output CIImage")
    }
}
