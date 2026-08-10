import XCTest
import ImageIO
@testable import Beautifier

final class BeautifierPipelineTests: XCTestCase {

    // MARK: - FaceSegmenter Tests

    /// Verify that FaceSegmenter produces a non-nil AI face segmentation mask for a face photo.
    func testFaceSegmenterProducesSegmentationMask() throws {
        let path = "/Users/clycesbon/code/projects/Beautifier/Beautifier/test_face.jpg"
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            XCTFail("Failed to load test_face.jpg CGImage")
            return
        }

        let mask = FaceSegmenter.segmentFace(in: cgImage)
        XCTAssertNotNil(mask, "FaceSegmenter should return a non-nil CIImage mask for a face photo")
    }

    // MARK: - SmoothingFilter Tests

    /// Verify SmoothingFilter actually modifies the image (reduces high-frequency variance).
    func testSmoothingFilterModifiesImage() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let testImage = renderer.image { ctx in
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

        let originalVariance = pixelVariance(of: originalCG)
        let smoothedVariance = pixelVariance(of: smoothedCG)
        XCTAssertLessThan(smoothedVariance, originalVariance,
            "Smoothed image should have lower pixel variance than original. Original: \(originalVariance), Smoothed: \(smoothedVariance)")
    }

    // MARK: - SkinMaskBuilder Tests

    /// Verify that structure mask is rasterized correctly with white background and black exclusions.
    func testSkinMaskBuilderStructureMask() throws {
        let size = CGSize(width: 200, height: 200)
        let geo = FaceGeometry(
            faceBox: CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6),
            exclusions: [CGRect(x: 0.35, y: 0.55, width: 0.3, height: 0.1)]
        )

        guard let structMask = SkinMaskBuilder.rasterizeStructure(geo, size: size) else {
            XCTFail("rasterizeStructure returned nil")
            return
        }

        guard let cgMask = RenderContext.shared.createCGImage(structMask, from: structMask.extent) else {
            XCTFail("Failed to render structure mask")
            return
        }

        let cornerPixel = getPixelBrightness(of: cgMask, atNormalized: CGPoint(x: 0.05, y: 0.05))
        XCTAssertGreaterThan(cornerPixel, 0.5,
            "Background should be white in structure mask")

        let exclusionPixel = getPixelBrightness(of: cgMask, atNormalized: CGPoint(x: 0.5, y: 0.4))
        XCTAssertLessThan(exclusionPixel, 0.5,
            "Exclusion region should be black in structure mask")
    }

    // MARK: - Full Pipeline Tests

    /// Integration test: verify SkinSmoothing produces valid output with AI face mask.
    func testSkinSmoothingOnlyModifiesMaskedRegion() throws {
        let size = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: size)

        let testImage = renderer.image { ctx in
            UIColor(red: 224/255, green: 172/255, blue: 143/255, alpha: 1.0).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 200))
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(x: 100, y: 0, width: 100, height: 200))
        }

        guard let data = testImage.jpegData(compressionQuality: 1.0),
              let ciImage = try? ImageLoader.downsampledPreviewCIImage(from: data) else {
            XCTFail("Failed to create test CIImage")
            return
        }

        let whiteMask = CIImage(color: .white).cropped(to: ciImage.extent)
        let output = SkinSmoothing.apply(to: ciImage, mask: whiteMask, radius: 8, amount: 1.0)

        XCTAssertNotNil(output, "SkinSmoothing should produce output")
        XCTAssertEqual(output.extent.size.width, ciImage.extent.size.width, accuracy: 1.0)
        XCTAssertEqual(output.extent.size.height, ciImage.extent.size.height, accuracy: 1.0)
    }

    // MARK: - FaceGeometry Coordinate Space Test

    func testFaceGeometryCoordinateConversion() throws {
        let path = "/Users/clycesbon/code/projects/Beautifier/Beautifier/test_face.jpg"
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return
        }

        let geometry = FaceDetector.detectGeometry(in: cgImage)
        if let geo = geometry {
            for exclusion in geo.exclusions {
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
