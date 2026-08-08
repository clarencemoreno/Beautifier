import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO

enum ImageProcessing {
    enum Error: LocalizedError {
        case invalidImageData
        case invalidCIImage
        case renderFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidImageData:
                return "The selected photo could not be decoded."
            case .invalidCIImage:
                return "The image could not be converted to a Core Image object."
            case .renderFailed(let stage):
                return "Rendering failed during \(stage)."
            }
        }
    }

    static func normalizedImage(from data: Data) throws -> UIImage {
        guard let image = UIImage(data: data) else {
            throw Error.invalidImageData
        }
        return normalizedOrientation(image)
    }

    static func downsampledPreviewCIImage(from data: Data, maxDimension: CGFloat) throws -> CIImage {
        let options: [NSString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else {
            throw Error.invalidImageData
        }

        return CIImage(cgImage: cgImage)
    }

    static func createUIImage(from ciImage: CIImage) throws -> UIImage {
        guard let cgImage = RenderContext.shared.createCGImage(ciImage, from: ciImage.extent) else {
            throw Error.renderFailed("preview")
        }
        return UIImage(cgImage: cgImage)
    }

    static func applySmoothing(to ciImage: CIImage, amount: Float) throws -> CIImage {
        guard amount > 0 else { return ciImage }

        let blurRadius: CGFloat = 8.0
        let blurred = ciImage
            .clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: blurRadius])
            .cropped(to: ciImage.extent)

        let dissolved = ciImage.applyingFilter("CIDissolveTransition", parameters: [
            kCIInputTargetImageKey: blurred,
            kCIInputTimeKey: amount
        ])

        return dissolved.cropped(to: ciImage.extent)
    }

    static func smoothingPreview(for ciImage: CIImage, amount: Float) throws -> UIImage {
        let output = try applySmoothing(to: ciImage, amount: amount)
        return try createUIImage(from: output)
    }

    static func renderUIImage(from ciImage: CIImage, scale: CGFloat = 1.0) throws -> UIImage {
        guard let cgImage = RenderContext.shared.createCGImage(ciImage, from: ciImage.extent) else {
            throw Error.renderFailed("final render")
        }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }

    static func normalizedOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        format.opaque = false
        let targetSize = image.size

        return UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
