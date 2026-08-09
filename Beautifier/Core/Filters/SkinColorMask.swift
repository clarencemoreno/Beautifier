import CoreImage
import CoreImage.CIFilterBuiltins

/// Produces a grayscale skin-probability mask from an input image.
///
/// Uses YCbCr color space analysis: skin tones fall within
/// Cb ∈ [0.30, 0.51] and Cr ∈ [0.52, 0.70] in the [0,1] range.
enum SkinColorMask {
    /// Returns a single-channel grayscale CIImage where white = skin, black = not-skin.
    static func apply(to image: CIImage) -> CIImage {
        // Step 1: Convert RGB to YCbCr components using CIColorMatrix.
        // Cb in R channel, Cr in G channel.
        let ycbcr = image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: -0.169, y: -0.331, z: 0.500, w: 0.0),
            "inputGVector": CIVector(x:  0.500, y: -0.419, z: -0.081, w: 0.0),
            "inputBVector": CIVector(x: 0.0, y: 0.0, z: 0.0, w: 0.0),
            "inputAVector": CIVector(x: 0.0, y: 0.0, z: 0.0, w: 1.0),
            "inputBiasVector": CIVector(x: 0.5, y: 0.5, z: 0.0, w: 0.0)
        ])

        // Step 2: Exact range mask calculation.
        // Cb >= 0.30
        let cbMin = ycbcr.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 40.0, y: 0.0, z: 0.0, w: 0.0),
            "inputGVector": CIVector(x: 40.0, y: 0.0, z: 0.0, w: 0.0),
            "inputBVector": CIVector(x: 40.0, y: 0.0, z: 0.0, w: 0.0),
            "inputAVector": CIVector(x: 0.0, y: 0.0, z: 0.0, w: 1.0),
            "inputBiasVector": CIVector(x: -0.30 * 40.0, y: -0.30 * 40.0, z: -0.30 * 40.0, w: 0.0)
        ]).applyingFilter("CIColorClamp", parameters: [
            "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
        ])

        // Cb <= 0.51
        let cbMax = ycbcr.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: -40.0, y: 0.0, z: 0.0, w: 0.0),
            "inputGVector": CIVector(x: -40.0, y: 0.0, z: 0.0, w: 0.0),
            "inputBVector": CIVector(x: -40.0, y: 0.0, z: 0.0, w: 0.0),
            "inputAVector": CIVector(x: 0.0, y: 0.0, z: 0.0, w: 1.0),
            "inputBiasVector": CIVector(x: 0.51 * 40.0, y: 0.51 * 40.0, z: 0.51 * 40.0, w: 0.0)
        ]).applyingFilter("CIColorClamp", parameters: [
            "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
        ])

        let cbMask = cbMin.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: cbMax])

        // Cr >= 0.52
        let crMin = ycbcr.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0.0, y: 40.0, z: 0.0, w: 0.0),
            "inputGVector": CIVector(x: 0.0, y: 40.0, z: 0.0, w: 0.0),
            "inputBVector": CIVector(x: 0.0, y: 40.0, z: 0.0, w: 0.0),
            "inputAVector": CIVector(x: 0.0, y: 0.0, z: 0.0, w: 1.0),
            "inputBiasVector": CIVector(x: -0.52 * 40.0, y: -0.52 * 40.0, z: -0.52 * 40.0, w: 0.0)
        ]).applyingFilter("CIColorClamp", parameters: [
            "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
        ])

        // Cr <= 0.70
        let crMax = ycbcr.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0.0, y: -40.0, z: 0.0, w: 0.0),
            "inputGVector": CIVector(x: 0.0, y: -40.0, z: 0.0, w: 0.0),
            "inputBVector": CIVector(x: 0.0, y: -40.0, z: 0.0, w: 0.0),
            "inputAVector": CIVector(x: 0.0, y: 0.0, z: 0.0, w: 1.0),
            "inputBiasVector": CIVector(x: 0.70 * 40.0, y: 0.70 * 40.0, z: 0.70 * 40.0, w: 0.0)
        ]).applyingFilter("CIColorClamp", parameters: [
            "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
        ])

        let crMask = crMin.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: crMax])

        let combined = cbMask.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: crMask])

        // Feather mask edges with small Gaussian blur
        let softened = combined
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 4.0])
            .cropped(to: image.extent)

        return softened
    }
}
