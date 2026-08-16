import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum ImageLoader {
    enum Error: LocalizedError {
        case invalidImageData
        case invalidCIImage

        var errorDescription: String? {
            switch self {
            case .invalidImageData:
                return "The selected photo could not be decoded."
            case .invalidCIImage:
                return "The image could not be converted to a Core Image object."
            }
        }
    }

    static func normalizedImage(from data: Data) throws -> UIImage {
        guard let image = UIImage(data: data) else {
            throw Error.invalidImageData
        }
        return normalizedOrientation(image)
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

    static func downsampledPreviewCIImage(from data: Data, maxDimension: CGFloat = 2048) throws -> CIImage {
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

    static func fullResolutionCIImage(from data: Data) throws -> CIImage {
        let options: [NSString: Any] = [
            kCGImageSourceShouldCache: false,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 16384,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]

        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else {
            throw Error.invalidImageData
        }

        return CIImage(cgImage: cgImage)
    }

    static func renderUIImage(from ciImage: CIImage, scale: CGFloat = 1.0) throws -> UIImage {
        guard let cgImage = RenderContext.shared.createCGImage(ciImage, from: ciImage.extent) else {
            throw ImageLoader.Error.invalidCIImage
        }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
}
