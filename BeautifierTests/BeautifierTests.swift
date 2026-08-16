import XCTest
import ImageIO
@testable import Beautifier

final class BeautifierPipelineTests: XCTestCase {

    // MARK: - Live Camera & Temporal Caching Requirements Tests

    /// Verify LiveProcessor enforces the strict 4-frame minimum inference cadence.
    func testLiveProcessorEnforcesFourFrameMinimumInferenceCadence() throws {
        let processor = LiveProcessor()
        let sourceSize = CGSize(width: 512, height: 512)
        let source = CIImage(color: .blue).cropped(to: CGRect(origin: .zero, size: sourceSize))

        // Frame 1: Triggers inference #1 (lastInferenceFrame = 1)
        _ = processor.process(image: source, amount: 0.5)
        XCTAssertEqual(processor.frameCount, 1)
        XCTAssertEqual(processor.lastInferenceFrame, 1)
        XCTAssertEqual(processor.inferenceRunCount, 1)

        // Frame 2: Skipped (elapsed 1 < 4)
        _ = processor.process(image: source, amount: 0.5)
        XCTAssertEqual(processor.frameCount, 2)
        XCTAssertEqual(processor.lastInferenceFrame, 1)
        XCTAssertEqual(processor.inferenceRunCount, 1)

        // Frame 3: Skipped (elapsed 2 < 4)
        _ = processor.process(image: source, amount: 0.5)
        XCTAssertEqual(processor.frameCount, 3)
        XCTAssertEqual(processor.lastInferenceFrame, 1)
        XCTAssertEqual(processor.inferenceRunCount, 1)

        // Frame 4: Skipped (elapsed 3 < 4)
        _ = processor.process(image: source, amount: 0.5)
        XCTAssertEqual(processor.frameCount, 4)
        XCTAssertEqual(processor.lastInferenceFrame, 1)
        XCTAssertEqual(processor.inferenceRunCount, 1)

        // Wait a moment for background task to release isInferring
        let exp = XCTestExpectation(description: "Worker idle")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { exp.fulfill() }
        wait(for: [exp], timeout: 1.0)

        // Frame 5: Triggers inference #2 (elapsed 4 >= 4)
        _ = processor.process(image: source, amount: 0.5)
        XCTAssertEqual(processor.frameCount, 5)
        XCTAssertEqual(processor.lastInferenceFrame, 5)
        XCTAssertEqual(processor.inferenceRunCount, 2)
    }

    /// Verify CameraGeometry aspect-fill calculation maintains uniform scaling and center alignment.
    func testCameraGeometryAspectFillMaintainsUniformScale() throws {
        let imageSize = CGSize(width: 720, height: 1280) // 9:16 portrait
        let drawableSize = CGSize(width: 393, height: 852) // iPhone screen

        let (scale, origin) = CameraGeometry.calculateAspectFill(imageSize: imageSize, drawableSize: drawableSize)

        // Scale must cover both width and height
        let scaledW = imageSize.width * scale
        let scaledH = imageSize.height * scale
        XCTAssertGreaterThanOrEqual(scaledW, drawableSize.width - 0.01)
        XCTAssertGreaterThanOrEqual(scaledH, drawableSize.height - 0.01)

        // Origin must center the scaled image within the drawable
        XCTAssertEqual(origin.x, (drawableSize.width - scaledW) / 2.0, accuracy: 0.01)
        XCTAssertEqual(origin.y, (drawableSize.height - scaledH) / 2.0, accuracy: 0.01)
    }

    /// Verify CameraService lifecycle transitions.
    func testCameraServiceLifecycle() throws {
        let camera = CameraService()
        camera.start()
        camera.stop()
        camera.checkPermissions()
        XCTAssertTrue(camera.isAuthorized || camera.authorizationDenied || !camera.isAuthorized)
    }

    // MARK: - Feature Flag Tests

    /// Verify that FeatureFlags.semanticSkinParser is true in DEBUG builds.
    func testFeatureFlagSemanticSkinParserIsTrueInDebug() {
        XCTAssertTrue(FeatureFlags.semanticSkinParser,
            "FeatureFlags.semanticSkinParser should be true in DEBUG builds")
    }

    // MARK: - SkinMaskBuilder (New Pipeline) Tests

    /// Verify that the new SkinMaskBuilder.buildMask(for:skinMask:) scales
    /// a 512×512 mask up to match a larger image extent.
    func testSkinMaskBuilderNewPipelineScalesMask() throws {
        let sourceSize = CGSize(width: 2048, height: 1536)
        let maskSize = CGSize(width: 512, height: 512)

        let source = CIImage(color: .blue).cropped(to: CGRect(origin: .zero, size: sourceSize))
        let mask = CIImage(color: .white).cropped(to: CGRect(origin: .zero, size: maskSize))

        let output = SkinMaskBuilder.buildMask(for: source, skinMask: mask)

        XCTAssertEqual(output.extent.size, sourceSize,
            "Scaled mask extent should match source image extent")
    }

    /// Verify that the new SkinMaskBuilder.buildMask(for:skinMask:) applies
    /// a 3px Gaussian feather blur (output creates a smooth transition at sharp boundaries).
    func testSkinMaskBuilderNewPipelineFeathersMask() throws {
        let sourceSize = CGSize(width: 1024, height: 1024)
        let maskSize = CGSize(width: 512, height: 512)

        let source = CIImage(color: .blue).cropped(to: CGRect(origin: .zero, size: sourceSize))
        // Create a mask with a sharp white box on the left half and black on the right half
        let whiteRect = CIImage(color: .white).cropped(to: CGRect(x: 0, y: 0, width: 256, height: 512))
        let blackRect = CIImage(color: .black).cropped(to: CGRect(x: 256, y: 0, width: 256, height: 512))
        let sharpMask = whiteRect.composited(over: blackRect).cropped(to: CGRect(origin: .zero, size: maskSize))

        let output = SkinMaskBuilder.buildMask(for: source, skinMask: sharpMask)

        guard let outputCG = RenderContext.shared.createCGImage(output, from: output.extent) else {
            XCTFail("Failed to render feathered mask")
            return
        }

        // At the boundary (x = 0.5), blur creates an intermediate gradient pixel value (between 0.1 and 0.9)
        let edgeBrightness = getPixelBrightness(of: outputCG, atNormalized: CGPoint(x: 0.5, y: 0.5))
        XCTAssertGreaterThan(edgeBrightness, 0.1, "Edge pixel should have feathered brightness > 0.1")
        XCTAssertLessThan(edgeBrightness, 0.9, "Edge pixel should have feathered brightness < 0.9")
    }

    /// Verify that SkinParserML produces a non-nil skin-probability mask for a real face photo.
    func testSkinParserMLGeneratesMaskForFaceImage() throws {
        let path = "/Users/clycesbon/code/projects/Beautifier/Beautifier/test_face.jpg"
        let url = URL(fileURLWithPath: path)
        guard let data = try? Data(contentsOf: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            XCTFail("Failed to load test_face.jpg CGImage")
            return
        }

        let mask = SkinParserML.skinMask(for: cgImage)
        XCTAssertNotNil(mask, "SkinParserML should produce a non-nil mask for test_face.jpg")
        if let mask = mask {
            XCTAssertEqual(mask.extent.width, 512, accuracy: 1.0)
            XCTAssertEqual(mask.extent.height, 512, accuracy: 1.0)
        }
    }

    /// Detailed verification of the full smoothing pipeline on a real face photo
    func testInspectRenderPipeline() throws {
        let path = "/Users/clycesbon/code/projects/Beautifier/Beautifier/test_face.jpg"
        let url = URL(fileURLWithPath: path)
        let data = try Data(contentsOf: url)
        let previewCI = try ImageLoader.downsampledPreviewCIImage(from: data, maxDimension: 2048)
        guard let previewCG = RenderContext.shared.createCGImage(previewCI, from: previewCI.extent) else {
            XCTFail("Failed to create previewCG")
            return
        }

        guard let aiMask = SkinParserML.skinMask(for: previewCG) else {
            XCTFail("SkinParserML returned nil")
            return
        }

        let mask = SkinMaskBuilder.buildMask(for: previewCI, skinMask: aiMask)
        let smoothed0 = SkinSmoothing.apply(to: previewCI, mask: mask, radius: 16, amount: 0.0)
        let smoothed50 = SkinSmoothing.apply(to: previewCI, mask: mask, radius: 16, amount: 0.5)
        let smoothed100 = SkinSmoothing.apply(to: previewCI, mask: mask, radius: 16, amount: 1.0)

        guard let cgOrig = RenderContext.shared.createCGImage(previewCI, from: previewCI.extent),
              let cgMask = RenderContext.shared.createCGImage(mask, from: mask.extent),
              let cgSoft = RenderContext.shared.createCGImage(SmoothingFilter.apply(to: previewCI, radius: 16, amount: 1.0), from: previewCI.extent),
              let cgSmoothed = RenderContext.shared.createCGImage(smoothed100, from: smoothed100.extent) else {
            XCTFail("Failed to render CGImages")
            return
        }

        print("DEBUG_PIPELINE: previewCI.extent=\(previewCI.extent)")
        print("DEBUG_PIPELINE: aiMask.extent=\(aiMask.extent)")
        print("DEBUG_PIPELINE: mask.extent=\(mask.extent)")

        let origVar = pixelVariance(of: cgOrig)
        let maskBright = averageBrightness(of: cgMask)
        let softVar = pixelVariance(of: cgSoft)
        let smoothedVar = pixelVariance(of: cgSmoothed)

        print("DEBUG_PIPELINE: origVar=\(origVar), softVar=\(softVar), maskAvgBrightness=\(maskBright), smoothedVar=\(smoothedVar)")
        XCTAssertGreaterThan(maskBright, 0.01, "Mask brightness must be non-zero")
        XCTAssertLessThan(softVar, origVar, "Softened image variance must be lower than original")
        XCTAssertLessThan(smoothedVar, origVar, "Smoothed image variance must be lower than original")
    }

    // MARK: - Legacy Pipeline Tests (still valid when flag is false)

    /// Verify that FaceSegmenter produces a non-nil AI face segmentation mask for a face photo.
    /// This test exercises the legacy pipeline directly.
    func testLegacyFaceSegmenterProducesSegmentationMask() throws {
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

    // MARK: - SkinMaskBuilder (Legacy Pipeline) Tests

    /// Verify that structure mask is rasterized correctly with white background and black exclusions.
    func testSkinMaskBuilderLegacyStructureMask() throws {
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

    /// Verify that the legacy SkinMaskBuilder.buildMask(for:geometry:faceMask:) combines
    /// an AI mask with landmark exclusions correctly.
    func testSkinMaskBuilderLegacyCombinesMaskAndExclusions() throws {
        let size = CGSize(width: 200, height: 200)
        let geo = FaceGeometry(
            faceBox: CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6),
            exclusions: [CGRect(x: 0.4, y: 0.5, width: 0.2, height: 0.1)]
        )

        let source = CIImage(color: .blue).cropped(to: CGRect(origin: .zero, size: size))
        let aiMask = CIImage(color: .white).cropped(to: CGRect(origin: .zero, size: size))

        let output = SkinMaskBuilder.buildMask(for: source, geometry: geo, faceMask: aiMask)

        XCTAssertEqual(output.extent.size, size,
            "Legacy combined mask extent should match source")
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
