import CoreImage
import CoreImage.CIFilterBuiltins

/// Produces a grayscale skin-probability mask from an input image.
///
/// Uses YCbCr color space analysis: skin tones typically fall within
/// Cb ∈ [0.30, 0.51] and Cr ∈ [0.52, 0.70] in the [0,1] range.
///
/// Implementation uses standard CIFilters instead of deprecated CIKL kernels
/// (CIColorKernel(source:) returns nil on iOS 17+).
enum SkinColorMask {
    /// Returns a single-channel grayscale CIImage where white = skin, black = not-skin.
    static func apply(to image: CIImage) -> CIImage {
        // Step 1: Convert RGB to YCbCr components using CIColorMatrix.
        // We need Cb and Cr values for skin classification.
        //
        // Standard RGB→YCbCr (BT.601):
        //   Cb = -0.169*R - 0.331*G + 0.500*B + 0.5
        //   Cr =  0.500*R - 0.419*G - 0.081*B + 0.5
        //
        // We'll output Cb in the red channel and Cr in the green channel.

        // CIColorMatrix: output.r = dot(input.rgba, rVector) + biasVector.r
        // For Cb in R channel: rVector = (-0.169, -0.331, 0.500, 0.0), bias.r = 0.5
        // For Cr in G channel: gVector = ( 0.500, -0.419, -0.081, 0.0), bias.g = 0.5
        let ycbcrImage = image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: -0.169, y: -0.331, z: 0.500, w: 0.0),
            "inputGVector": CIVector(x:  0.500, y: -0.419, z: -0.081, w: 0.0),
            "inputBVector": CIVector(x: 0.0, y: 0.0, z: 0.0, w: 0.0),
            "inputAVector": CIVector(x: 0.0, y: 0.0, z: 0.0, w: 1.0),
            "inputBiasVector": CIVector(x: 0.5, y: 0.5, z: 0.0, w: 0.0)
        ])
        // Now: R channel = Cb, G channel = Cr

        // Step 2: Create skin range masks using threshold logic.
        // Skin range: Cb ∈ [0.30, 0.51], Cr ∈ [0.52, 0.70]
        //
        // We can't do smoothstep natively, but we can approximate binary classification
        // by mapping the Cb/Cr values through a series of color matrix + clamp operations.
        //
        // Strategy: Remap Cb from [0.30,0.51] → [0,1], clamp, then do the same for Cr.
        // Combine by multiplying.

        // Remap Cb (in R channel): out = (Cb - 0.30) / (0.51 - 0.30) = (Cb - 0.30) / 0.21
        // Remap Cr (in G channel): out = (Cr - 0.52) / (0.70 - 0.52) = (Cr - 0.52) / 0.18
        let remapped = ycbcrImage.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 1.0 / 0.21, y: 0.0, z: 0.0, w: 0.0),
            "inputGVector": CIVector(x: 0.0, y: 1.0 / 0.18, z: 0.0, w: 0.0),
            "inputBVector": CIVector(x: 0.0, y: 0.0, z: 0.0, w: 0.0),
            "inputAVector": CIVector(x: 0.0, y: 0.0, z: 0.0, w: 1.0),
            "inputBiasVector": CIVector(x: -0.30 / 0.21, y: -0.52 / 0.18, z: 0.0, w: 0.0)
        ])
        // R = (Cb - 0.30) / 0.21  → in [0,1] if Cb in skin range
        // G = (Cr - 0.52) / 0.18  → in [0,1] if Cr in skin range

        // Step 3: Clamp to [0,1] to create binary-ish mask per channel
        let clamped = remapped.applyingFilter("CIColorClamp", parameters: [
            "inputMinComponents": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputMaxComponents": CIVector(x: 1, y: 1, z: 0, w: 1)
        ])

        // Step 4: Create inverse masks (1.0 - value) and multiply.
        // We want: mask = clamp(remap_cb) * clamp(remap_cr)
        // But we also need to ensure values at the boundaries are soft.
        // For simplicity, apply a small Gaussian blur at the end for soft edges.

        // Multiply R and G channels together into a single channel.
        // Use CIColorMatrix to output R*G approximation:
        // We'll put the product in all RGB channels.
        // Since we can't multiply channels with CIColorMatrix alone,
        // we use a different approach: extract channels as separate images
        // and use CIMultiplyCompositing.

        // Extract R channel (Cb mask) as grayscale
        let cbMask = clamped.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 1.0, y: 0.0, z: 0.0, w: 0.0),
            "inputGVector": CIVector(x: 1.0, y: 0.0, z: 0.0, w: 0.0),
            "inputBVector": CIVector(x: 1.0, y: 0.0, z: 0.0, w: 0.0),
            "inputAVector": CIVector(x: 0.0, y: 0.0, z: 0.0, w: 1.0),
            "inputBiasVector": CIVector(x: 0.0, y: 0.0, z: 0.0, w: 0.0)
        ])

        // Extract G channel (Cr mask) as grayscale
        let crMask = clamped.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0.0, y: 1.0, z: 0.0, w: 0.0),
            "inputGVector": CIVector(x: 0.0, y: 1.0, z: 0.0, w: 0.0),
            "inputBVector": CIVector(x: 0.0, y: 1.0, z: 0.0, w: 0.0),
            "inputAVector": CIVector(x: 0.0, y: 0.0, z: 0.0, w: 1.0),
            "inputBiasVector": CIVector(x: 0.0, y: 0.0, z: 0.0, w: 0.0)
        ])

        // Multiply: skin = cbMask * crMask (white only where BOTH are in range)
        let combined = cbMask.applyingFilter("CIMultiplyCompositing", parameters: [
            kCIInputBackgroundImageKey: crMask
        ])

        // Step 5: Soften edges with small Gaussian blur for smooth transitions
        let softened = combined
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 2.0])
            .cropped(to: image.extent)

        return softened
    }
}
