import Metal
import QuartzCore

final class MetalContext {

    static let shared = MetalContext()

    let device: MTLDevice
    let commandQueue: MTLCommandQueue

    private init() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue()
        else {
            fatalError("❌ Metal not supported")
        }

        self.device = device
        self.commandQueue = queue
    }
}
