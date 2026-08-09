import CoreImage
import CoreImage.CIFilterBuiltins

enum SmoothingFilter {
    /// Skin smoothing filter using Gaussian blur with dissolve blending.
    ///
    /// For the skin-aware pipeline, the mask handles targeting (only skin gets smoothed).
    /// This filter handles the actual smoothing operation.
    ///
    /// - Parameters:
    ///   - ciImage: The source image to smooth.
    ///   - radius: Controls the spatial extent of the Gaussian blur.
    ///   - amount: Blending amount between original and smoothed [0..1].
    /// - Returns: Smoothed image blended with original.
    static func apply(to ciImage: CIImage, radius: CGFloat = 8.0, amount: Float) -> CIImage {
        guard amount > 0 else { return ciImage }

        // Apply Gaussian blur — this handles the actual smoothing.
        // The edge-preservation is handled by the skin mask in SkinSmoothing,
        // not by this filter alone.
        let blurred = ciImage
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [
                kCIInputRadiusKey: radius * CGFloat(amount)
            ])
            .cropped(to: ciImage.extent)

        // Blend smoothed with original using dissolve transition
        let blended = ciImage.applyingFilter("CIDissolveTransition", parameters: [
            kCIInputTargetImageKey: blurred,
            kCIInputTimeKey: amount
        ])

        return blended.cropped(to: ciImage.extent)
    }
}
