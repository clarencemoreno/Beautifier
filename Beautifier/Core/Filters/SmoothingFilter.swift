import CoreImage
import CoreImage.CIFilterBuiltins

enum SmoothingFilter {
    /// Applies Gaussian blur smoothing blended via dissolve transition.
    ///
    /// - Parameters:
    ///   - ciImage: The source image to smooth.
    ///   - radius: Fixed spatial extent of the Gaussian blur.
    ///   - amount: Intensity factor [0..1] controlling dissolve transition blend time.
    /// - Returns: Smoothed image blended with original.
    static func apply(to ciImage: CIImage, radius: CGFloat = 8.0, amount: Float) -> CIImage {
        guard amount > 0 else { return ciImage }

        let blurred = ciImage
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [
                kCIInputRadiusKey: radius
            ])
            .cropped(to: ciImage.extent)

        let blended = ciImage.applyingFilter("CIDissolveTransition", parameters: [
            kCIInputTargetImageKey: blurred,
            kCIInputTimeKey: amount
        ])

        return blended.cropped(to: ciImage.extent)
    }
}
