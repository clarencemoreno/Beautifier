import XCTest
@testable import Beautifier

final class BeautifierPipelineTests: XCTestCase {

    func testFaceDetectionAndSkinMask() throws {
        let bundle = Bundle(for: BeautifierPipelineTests.self)
        guard let url = bundle.url(forResource: "test_face", withExtension: "jpg") ??
                        Bundle.main.url(forResource: "test_face", withExtension: "jpg"),
              let data = try? Data(contentsOf: url),
              let normalized = try? ImageLoader.normalizedImage(from: data),
              let cgImage = normalized.cgImage else {
            XCTFail("Failed to load test_face.jpg")
            return
        }

        let geometry = FaceDetector.detectGeometry(in: cgImage)
        XCTAssertNotNil(geometry, "FaceDetector should detect face in test_face.jpg")

        if let geometry {
            let previewCI = try ImageLoader.downsampledPreviewCIImage(from: data)
            let mask = SkinMaskBuilder.buildMask(for: previewCI, geometry: geometry)
            XCTAssertNotNil(mask, "SkinMaskBuilder should generate mask")
            
            let output = SkinSmoothing.apply(to: previewCI, mask: mask, radius: 8, amount: 0.5)
            XCTAssertNotNil(output, "SkinSmoothing filter should produce output CIImage")
        }
    }
}
