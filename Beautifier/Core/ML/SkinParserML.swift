import Vision
import CoreML

/// Runs the BiSeNet face-parsing Core ML model and returns a grayscale
/// skin-probability `CIImage` at model resolution (512×512).
enum SkinParserML {

    private static let request: VNCoreMLRequest = {
        let config = MLModelConfiguration()
        config.computeUnits = .all          // ANE on device, CPU on Simulator
        let model = try! FaceParserSkin(configuration: config).model
        let req = try! VNCoreMLRequest(model: model)
        req.imageCropAndScaleOption = .scaleFill   // center-crop to 512×512
        return req
    }()

    /// Grayscale skin-probability mask at model resolution (512×512).
    /// Returns `nil` when the model fails to run.
    static func skinMask(for cgImage: CGImage) -> CIImage? {
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        guard (try? handler.perform([request])) != nil,
              let obs = request.results?.first as? VNPixelBufferObservation
        else { return nil }
        return CIImage(cvPixelBuffer: obs.pixelBuffer)
    }
}
