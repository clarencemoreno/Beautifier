import CoreImage
import CoreImage.CIFilterBuiltins

enum SmoothingFilter {
    static func apply(to ciImage: CIImage, radius: CGFloat = 20.0, amount: Float) -> CIImage {
        guard amount > 0 else { return ciImage }

        // Radius is static; `amount` strictly controls the dissolve transition.
        let blurred = ciImage
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
            .cropped(to: ciImage.extent)

        let blended = ciImage.applyingFilter("CIDissolveTransition", parameters: [
            kCIInputTargetImageKey: blurred,
            kCIInputTimeKey: amount
        ])
        return blended.cropped(to: ciImage.extent)
    }
}
