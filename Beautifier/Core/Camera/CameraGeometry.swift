import CoreGraphics

enum CameraGeometry {
    /// Calculates the uniform scale and centered origin for aspect-fill rendering without stretching.
    static func calculateAspectFill(imageSize: CGSize, drawableSize: CGSize) -> (scale: CGFloat, origin: CGPoint) {
        guard imageSize.width > 0, imageSize.height > 0,
              drawableSize.width > 0, drawableSize.height > 0 else {
            return (1.0, .zero)
        }

        let scale = max(drawableSize.width / imageSize.width, drawableSize.height / imageSize.height)
        let scaledW = imageSize.width * scale
        let scaledH = imageSize.height * scale
        let originX = (drawableSize.width - scaledW) / 2.0
        let originY = (drawableSize.height - scaledH) / 2.0

        return (scale, CGPoint(x: originX, y: originY))
    }
}
