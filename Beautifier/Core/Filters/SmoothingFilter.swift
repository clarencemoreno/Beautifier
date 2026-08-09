import CoreImage
import CoreImage.CIFilterBuiltins

enum SmoothingFilter {
    static func apply(to ciImage: CIImage, radius: CGFloat = 8.0, amount: Float) -> CIImage {
        guard amount > 0 else { return ciImage }

        let blurred = ciImage
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius])
            .cropped(to: ciImage.extent)

        let dissolved = ciImage.applyingFilter("CIDissolveTransition", parameters: [
            kCIInputTargetImageKey: blurred,
            kCIInputTimeKey: amount
        ])

        return dissolved.cropped(to: ciImage.extent)
    }
}
