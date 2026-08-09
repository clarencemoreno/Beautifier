import CoreImage

enum SkinColorMask {
    private static let kernel: CIColorKernel? = {
        let code = """
        kernel vec4 skinColorMask(__sample color) {
            float cb = -0.169 * color.r - 0.331 * color.g + 0.500 * color.b + 0.5;
            float cr =  0.500 * color.r - 0.419 * color.g - 0.081 * color.b + 0.5;

            float s = smoothstep(0.30, 0.34, cb) * (1.0 - smoothstep(0.47, 0.51, cb))
                    * smoothstep(0.52, 0.56, cr) * (1.0 - smoothstep(0.66, 0.70, cr));
            return vec4(s, s, s, 1.0);
        }
        """
        return CIColorKernel(source: code)
    }()

    static func apply(to image: CIImage) -> CIImage {
        kernel?.apply(extent: image.extent, arguments: [image]) ?? image
    }
}
