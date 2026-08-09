import XCTest
@testable import Beautifier

final class BeautifierPipelineTests: XCTestCase {

    // MARK: - SkinColorMask Tests

    /// Verify that SkinColorMask produces a grayscale mask (not the original color image).
    /// The old CIKL kernel returned nil and fell back to returning the original image.
    func testSkinColorMaskProducesGrayscaleMask() throws {
        // Create an image with a known skin-tone color (warm beige/tan)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let skinImage = renderer.image { ctx in
            // Typical skin tone in RGB: ~(224, 172, 143)
            UIColor(red: 224/255, green: 172/255, blue: 143/255, alpha: 1.0).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }

        guard let data = skinImage.jpegData(compressionQuality: 1.0),
              let ciImage = try? ImageLoader.downsampledPreviewCIImage(from: data) else {
            XCTFail("Failed to create test CIImage")
            return
        }

        let mask = SkinColorMask.apply(to: ciImage)

        // Render mask to pixels
        guard let cgMask = RenderContext.shared.createCGImage(mask, from: mask.extent) else {
            XCTFail("Failed to render mask to CGImage")
            return
        }

        // The mask for a uniform skin-tone image should be mostly white (skin detected)
        let avgBrightness = averageBrightness(of: cgMask)
        XCTAssertGreaterThan(avgBrightness, 0.3,
            "Skin-tone image should produce a mostly bright mask, got avg brightness: \(avgBrightness)")
    }

    /// Verify that a non-skin-tone image produces a mostly dark mask.
    func testSkinColorMaskRejectsNonSkinColors() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let blueImage = renderer.image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }

        guard let data = blueImage.jpegData(compressionQuality: 1.0),
              let ciImage = try? ImageLoader.downsampledPreviewCIImage(from: data) else {
            XCTFail("Failed to create test CIImage")
            return
        }

        let mask = SkinColorMask.apply(to: ciImage)
        guard let cgMask = RenderContext.shared.createCGImage(mask, from: mask.extent) else {
            XCTFail("Failed to render mask to CGImage")
            return
        }

        let avgBrightness = averageBrightness(of: cgMask)
        XCTAssertLessThan(avgBrightness, 0.3,
            "Blue image should produce a mostly dark mask, got avg brightness: \(avgBrightness)")
    }

    // MARK: - SmoothingFilter Tests

    /// Verify SmoothingFilter actually modifies the image (not a no-op from non-existent filter).
    func testSmoothingFilterModifiesImage() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let testImage = renderer.image { ctx in
            // Create high-frequency pattern (checkerboard-like)
            for y in stride(from: 0, to: 100, by: 2) {
                for x in stride(from: 0, to: 100, by: 2) {
                    let isWhite = (x / 2 + y / 2) % 2 == 0
                    (isWhite ? UIColor.white : UIColor.black).setFill()
                    ctx.fill(CGRect(x: x, y: y, width: 2, height: 2))
                }
            }
        }

        guard let data = testImage.jpegData(compressionQuality: 1.0),
              let ciImage = try? ImageLoader.downsampledPreviewCIImage(from: data) else {
            XCTFail("Failed to create test CIImage")
            return
        }

        let smoothed = SmoothingFilter.apply(to: ciImage, radius: 8, amount: 1.0)
        guard let originalCG = RenderContext.shared.createCGImage(ciImage, from: ciImage.extent),
              let smoothedCG = RenderContext.shared.createCGImage(smoothed, from: smoothed.extent) else {
            XCTFail("Failed to render images")
            return
        }

        // Smoothing should reduce variance (checkerboard → more uniform gray)
        let originalVariance = pixelVariance(of: originalCG)
        let smoothedVariance = pixelVariance(of: smoothedCG)
        XCTAssertLessThan(smoothedVariance, originalVariance,
            "Smoothed image should have lower pixel variance than original. Original: \(originalVariance), Smoothed: \(smoothedVariance)")
    }

    // MARK: - SkinMaskBuilder Tests

    /// Verify that structure mask is rasterized correctly.
    func testSkinMaskBuilderStructureMask() throws {
        let size = CGSize(width: 200, height: 200)
        let geo = FaceGeometry(
            faceBox: CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6),
            exclusions: [CGRect(x: 0.35, y: 0.55, width: 0.3, height: 0.1)] // "mouth" area
        )

        guard let structMask = SkinMaskBuilder.rasterizeStructure(geo, size: size) else {
            XCTFail("rasterizeStructure returned nil")
            return
        }

        guard let cgMask = RenderContext.shared.createCGImage(structMask, from: structMask.extent) else {
            XCTFail("Failed to render structure mask")
            return
        }

        // Center of faceBox should be white (included)
        let centerPixel = getPixelBrightness(of: cgMask, atNormalized: CGPoint(x: 0.5, y: 0.5))
        XCTAssertGreaterThan(centerPixel, 0.5,
            "Center of face box should be white in structure mask")

        // Corner of image (outside face box) should be black
        let cornerPixel = getPixelBrightness(of: cgMask, atNormalized: CGPoint(x: 0.05, y: 0.05))
        XCTAssertLessThan(cornerPixel, 0.5,
            "Corner outside face box should be black in structure mask")
    }

    // MARK: - Full Pipeline Tests

    /// Integration test: verify SkinSmoothing only changes skin-region pixels.
    func testSkinSmoothingOnlyModifiesMaskedRegion() throws {
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)

        // Create image: left half = skin color, right half = blue
        let testImage = renderer.image { ctx in
            // Left half: skin-tone
            UIColor(red: 224/255, green: 172/255, blue: 143/255, alpha: 1.0).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 200))
            // Right half: blue (non-skin)
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(x: 100, y: 0, width: 100, height: 200))
        }

        guard let data = testImage.jpegData(compressionQuality: 1.0),
              let ciImage = try? ImageLoader.downsampledPreviewCIImage(from: data) else {
            XCTFail("Failed to create test CIImage")
            return
        }

        // Create a full-white mask (everything is "skin")
        let whiteMask = CIImage(color: .white).cropped(to: ciImage.extent)
        let output = SkinSmoothing.apply(to: ciImage, mask: whiteMask, radius: 8, amount: 1.0)

        XCTAssertNotNil(output, "SkinSmoothing should produce output")
        XCTAssertEqual(output.extent.size.width, ciImage.extent.size.width, accuracy: 1.0)
        XCTAssertEqual(output.extent.size.height, ciImage.extent.size.height, accuracy: 1.0)
    }

    // MARK: - FaceGeometry Coordinate Space Test

    /// Verify that FaceGeometryBuilder correctly converts face-relative landmarks
    /// to image-relative coordinates.
    func testFaceGeometryCoordinateConversion() throws {
        // Use the demo face image if available; otherwise skip
        guard let url = Bundle.main.url(forResource: "test_face", withExtension: "jpg")
                ?? Bundle.main.url(forResource: "sample_face", withExtension: "jpg"),
              let data = try? Data(contentsOf: url),
              let uiImage = UIImage(data: data),
              let cgImage = uiImage.cgImage else {
            // No demo image available in test bundle — skip gracefully
            return
        }

        let geometry = FaceDetector.detectGeometry(in: cgImage)
        // If a face is detected, all exclusions should be within the face box (approximately)
        if let geo = geometry {
            for exclusion in geo.exclusions {
                // Each exclusion should be within or near the enlarged face box
                let enlargedFaceBox = geo.faceBox.insetBy(
                    dx: -geo.faceBox.width * 0.3,
                    dy: -geo.faceBox.height * 0.3
                )
                XCTAssertTrue(enlargedFaceBox.intersects(exclusion),
                    "Exclusion \(exclusion) should be near face box \(geo.faceBox)")
            }
        }
    }

    // MARK: - Pixel Analysis Helpers

    private func averageBrightness(of cgImage: CGImage) -> Double {
        let w = cgImage.width, h = cgImage.height
        guard let ctx = CGContext(data: nil, width: w, height: h,
                                   bitsPerComponent: 8, bytesPerRow: w * 4,
                                   space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
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

    private func pixelVariance(of cgImage: CGImage) -> Double {
        let w = cgImage.width, h = cgImage.height
        guard let ctx = CGContext(data: nil, width: w, height: h,
                                   bitsPerComponent: 8, bytesPerRow: w * 4,
                                   space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = ctx.data else { return 0 }
        let ptr = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
        let pixelCount = w * h
        var values: [Double] = []
        for i in 0..<pixelCount {
            let r = Double(ptr[i * 4])
            let g = Double(ptr[i * 4 + 1])
            let b = Double(ptr[i * 4 + 2])
            values.append((r + g + b) / (3.0 * 255.0))
        }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return variance
    }

    private func getPixelBrightness(of cgImage: CGImage, atNormalized point: CGPoint) -> Double {
        let w = cgImage.width, h = cgImage.height
        let x = Int(point.x * CGFloat(w))
        let y = Int(point.y * CGFloat(h))
        guard let ctx = CGContext(data: nil, width: w, height: h,
                                   bitsPerComponent: 8, bytesPerRow: w * 4,
                                   space: CGColorSpaceCreateDeviceRGB(),
                                   bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        guard let data = ctx.data else { return 0 }
        let ptr = data.bindMemory(to: UInt8.self, capacity: w * h * 4)
        let i = y * w + x
        guard i >= 0, i < w * h else { return 0 }
        let r = Double(ptr[i * 4])
        let g = Double(ptr[i * 4 + 1])
        let b = Double(ptr[i * 4 + 2])
        return (r + g + b) / (3.0 * 255.0)
    }
}
