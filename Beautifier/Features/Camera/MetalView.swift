import SwiftUI
import MetalKit
import CoreImage

struct MetalView: UIViewRepresentable {
    let pixelBuffer: CVPixelBuffer?
    let amount: Float
    let processor: LiveProcessor

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
        uiView.setNeedsDisplay()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(processor: processor)
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        var currentPixelBuffer: CVPixelBuffer?
        var currentAmount: Float = 0.5
        weak var mtkView: MTKView?

        private let processor: LiveProcessor
        private let commandQueue: MTLCommandQueue?

        init(processor: LiveProcessor) {
            self.processor = processor
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

            let rawCIImage = CIImage(cvPixelBuffer: pixelBuffer)
            let processedImage = processor.process(image: rawCIImage, amount: currentAmount)

            let drawableSize = view.drawableSize
            guard drawableSize.width > 0, drawableSize.height > 0 else { return }

            // Aspect-fill viewport scaling (D6)
            let scale = max(drawableSize.width / processedImage.extent.width,
                            drawableSize.height / processedImage.extent.height)
            let scaledW = processedImage.extent.width * scale
            let scaledH = processedImage.extent.height * scale
            let originX = (drawableSize.width - scaledW) / 2.0
            let originY = (drawableSize.height - scaledH) / 2.0

            let renderImage = processedImage
                .transformed(by: CGAffineTransform(scaleX: scale, y: scale))
                .transformed(by: CGAffineTransform(translationX: originX, y: originY))
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
