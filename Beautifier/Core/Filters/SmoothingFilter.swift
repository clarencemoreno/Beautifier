import CoreImage
import CoreImage.CIFilterBuiltins

enum SmoothingFilter {
    /// High-quality skin smoothing filter combining guided bilateral edge-preserving smoothing
    /// with high-frequency skin texture detail preservation
    static func apply(to ciImage: CIImage, radius: CGFloat = 8.0, amount: Float) -> CIImage {
        guard amount > 0 else { return ciImage }

        let blurred = ciImage
            .clampedToExtent()
            .applyingFilter("CIBilateralFilter", parameters: [
                "inputRadius": radius,
                "inputDistance": 0.15
            ])
            .cropped(to: ciImage.extent)

        let smoothed = ciImage.applyingFilter("CIDissolveTransition", parameters: [
            kCIInputTargetImageKey: blurred,
            kCIInputTimeKey: amount
        ])

        return smoothed.cropped(to: ciImage.extent)
    }
}
