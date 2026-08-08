import CoreImage
import Metal

enum RenderContext {
    static let shared: CIContext = {
        if let device = MTLCreateSystemDefaultDevice() {
            return CIContext(mtlDevice: device,
                             options: [.cacheIntermediates: false])
        }

        return CIContext(options: [.cacheIntermediates: false])
    }()
}
