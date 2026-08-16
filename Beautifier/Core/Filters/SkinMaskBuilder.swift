import CoreImage
import CoreGraphics

enum SkinMaskBuilder {
    /// Rasterizes facial feature exclusions (eyes, brows, lips) into a structure mask.
    /// Background is white (1.0), exclusion rects are black (0.0).
    static func rasterizeStructure(_ geo: FaceGeometry, size: CGSize) -> CIImage? {
        let w = Int(size.width), h = Int(size.height)
        guard let ctx = CGContext(data: nil, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: w,
                                  space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue)
        else { return nil }

        func px(_ r: CGRect) -> CGRect {
            CGRect(x: r.minX * size.width,
                   y: r.minY * size.height,
                   width: r.width * size.width,
                   height: r.height * size.height)
        }

        // Start with white background
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

        // Draw feature exclusions in black
        ctx.setFillColor(CGColor(gray: 0, alpha: 1))
        geo.exclusions.forEach { ctx.fill(px($0)) }

        return ctx.makeImage().map(CIImage.init(cgImage:))
    }

    /// Combines AI face segmentation mask with landmark exclusion structure.
    ///
    /// - Parameters:
    ///   - image: Source input CIImage.
    ///   - geometry: Face geometry containing exclusion regions.
    ///   - faceMask: Hardware-accelerated AI face segmentation mask.
    /// - Returns: Final feathered skin mask CIImage.
    static func buildMask(for image: CIImage, geometry: FaceGeometry, faceMask: CIImage) -> CIImage {
        // 1. Scale AI face mask to match input image extent
        let scaleX = image.extent.width / faceMask.extent.width
        let scaleY = image.extent.height / faceMask.extent.height
        let scaledMask = faceMask.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        // 2. Rasterize landmark exclusions
        guard let structure = rasterizeStructure(geometry, size: image.extent.size) else {
            return scaledMask.clampedToExtent()
                .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 4])
                .cropped(to: image.extent)
        }

        // 3. Multiply AI mask with exclusion structure
        let combined = scaledMask.applyingFilter(
            "CIMultiplyCompositing",
            parameters: [kCIInputBackgroundImageKey: structure]
        )

        // 4. Feather mask edges with small Gaussian blur
        return combined.clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 4])
            .cropped(to: image.extent)
    }

    // MARK: — Semantic Skin Parser Path (Week 3.5)

    /// Combines an ML-derived semantic skin mask with the source image.
    ///
    /// This is the **new** pipeline: the model's skin class already excludes
    /// eyes, brows, lips, hair, clothing, and background — no rectangles needed.
    ///
    /// - Parameters:
    ///   - image: Source input CIImage.
    ///   - skinMask: Grayscale skin-probability mask from `SkinParserML` (512×512).
    /// - Returns: Final feathered skin mask CIImage matching `image` extent.
    static func buildMask(for image: CIImage, skinMask: CIImage) -> CIImage {
        let scaleX = image.extent.width  / skinMask.extent.width
        let scaleY = image.extent.height / skinMask.extent.height
        let scaledMask = skinMask
            .transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 3])
            .cropped(to: image.extent)

        // Compute high-contrast edges from image to protect facial contours (jawline, nose contours, eyelid creases)
        let edges = image
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0.0, kCIInputContrastKey: 1.5])
            .applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: 8.0])
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 1.5])
            .cropped(to: image.extent)

        // Invert edges: 1.0 on smooth regions, 0.0 on sharp contour edges
        let invertedEdges = edges.applyingFilter("CIColorInvert")

        // Multiply skin mask with inverted edges so sharp contour lines are not blurred
        let protectedMask = scaledMask.applyingFilter("CIMultiplyCompositing", parameters: [
            kCIInputBackgroundImageKey: invertedEdges
        ]).cropped(to: image.extent)

        return protectedMask
    }
}
