import CoreImage

enum SkinSmoothing {
    static func apply(to image: CIImage, mask: CIImage,
                      radius: CGFloat, amount: Float) -> CIImage {
        let softened = SmoothingFilter.apply(to: image, radius: radius, amount: amount)
        return softened.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: image,
            kCIInputMaskImageKey: mask
        ])
    }
}
