import CoreImage
import CoreImage.CIFilterBuiltins

enum SmoothingFilter {
    /// Applies skin smoothing with dynamic radius scaled by slider amount.
    ///
    /// - Parameters:
    ///   - ciImage: The source image to smooth.
    ///   - radius: Blur radius for skin softening.
    ///   - amount: Intensity factor [0..1] controlling blur radius and blend transition.
    /// - Returns: Smoothed image blended with original.
    static func apply(to ciImage: CIImage, radius: CGFloat = 20.0, amount: Float) -> CIImage {
        guard amount > 0 else { return ciImage }

        let effectiveRadius = max(1.0, radius * CGFloat(amount))

        let blurred = ciImage
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [
                kCIInputRadiusKey: effectiveRadius
            ])
            .cropped(to: ciImage.extent)

        let blended = ciImage.applyingFilter("CIDissolveTransition", parameters: [
            kCIInputTargetImageKey: blurred,
            kCIInputTimeKey: amount
        ])

        return blended.cropped(to: ciImage.extent)
    }
}
