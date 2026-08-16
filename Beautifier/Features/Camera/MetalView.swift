import SwiftUI
import MetalKit
import CoreImage

struct MetalView: UIViewRepresentable {
    let pixelBuffer: CVPixelBuffer?
    let amount: Float
    let processor: LiveProcessor
    var onFPSUpdate: ((Double) -> Void)? = nil

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.framebufferOnly = false
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = true
        mtkView.delegate = context.coordinator
        context.coordinator.mtkView = mtkView
        return mtkView
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.currentPixelBuffer = pixelBuffer
        context.coordinator.currentAmount = amount
        context.coordinator.onFPSUpdate = onFPSUpdate
        uiView.setNeedsDisplay()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(processor: processor, onFPSUpdate: onFPSUpdate)
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        var currentPixelBuffer: CVPixelBuffer?
        var currentAmount: Float = 0.5
        var onFPSUpdate: ((Double) -> Void)?
        weak var mtkView: MTKView?

        private let processor: LiveProcessor
        private let commandQueue: MTLCommandQueue?
        private var frameTimestamps: [CFTimeInterval] = []

        init(processor: LiveProcessor, onFPSUpdate: ((Double) -> Void)?) {
            self.processor = processor
            self.onFPSUpdate = onFPSUpdate
            let device = MTLCreateSystemDefaultDevice()
            self.commandQueue = device?.makeCommandQueue()
            super.init()
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            guard let pixelBuffer = currentPixelBuffer,
                  let currentDrawable = view.currentDrawable,
                  let commandQueue = self.commandQueue,
                  let commandBuffer = commandQueue.makeCommandBuffer() else {
                return
            }

            // Instrumented Rolling FPS calculation
            let now = CACurrentMediaTime()
            frameTimestamps.append(now)
            frameTimestamps = frameTimestamps.filter { now - $0 <= 1.0 }
            let measuredFPS = Double(frameTimestamps.count)
            DispatchQueue.main.async {
                self.onFPSUpdate?(measuredFPS)
            }

            let rawCIImage = CIImage(cvPixelBuffer: pixelBuffer)
            let processedImage = processor.process(image: rawCIImage, amount: currentAmount, buffer: pixelBuffer)

            let drawableSize = view.drawableSize
            guard drawableSize.width > 0, drawableSize.height > 0 else { return }

            // Aspect-fill viewport scaling using CameraGeometry (D6)
            let (scale, origin) = CameraGeometry.calculateAspectFill(
                imageSize: processedImage.extent.size,
                drawableSize: drawableSize
            )

            let renderImage = processedImage
                .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                .transformed(by: CGAffineTransform(translationX: origin.x, y: origin.y))
                .cropped(to: CGRect(origin: .zero, size: drawableSize))

            RenderContext.shared.render(
                renderImage,
                to: currentDrawable.texture,
                commandBuffer: commandBuffer,
                bounds: CGRect(origin: .zero, size: drawableSize),
                colorSpace: CGColorSpaceCreateDeviceRGB()
            )

            commandBuffer.present(currentDrawable)
            commandBuffer.commit()
        }
    }
}
