import Foundation
import CoreVideo
import CoreMedia

protocol FrameConsumer: AnyObject {
    func consume(pixelBuffer: CVPixelBuffer, time: CMTime)
}

final class FrameGate {

    // MARK: - Config
    private let targetFPS: Double
    private let minFrameInterval: CMTime

    // MARK: - State
    private var lastFrameTime: CMTime = .zero
    private var isProcessing = false

    // MARK: - Consumer
    weak var consumer: FrameConsumer?

    // MARK: - Queue
    private let gateQueue = DispatchQueue(
        label: "frame.gate.queue",
        qos: .userInteractive
    )

    // MARK: - Init
    init(targetFPS: Double? = nil) {
        // Используем FPS из DeviceCapabilities если не указано явно
        let fps = targetFPS ?? Double(DeviceCapabilities.current.maxFPS)
        self.targetFPS = fps
        self.minFrameInterval = CMTime(
            seconds: 1.0 / fps,
            preferredTimescale: 600
        )
        print("🎯 FrameGate initialized with targetFPS: \(fps)")
    }

    // MARK: - Public API
    func push(pixelBuffer: CVPixelBuffer, time: CMTime) {
        gateQueue.async {
            // Drop if busy
            if self.isProcessing {
                return
            }

            // Drop if too early
            if self.lastFrameTime != .zero {
                let delta = CMTimeSubtract(time, self.lastFrameTime)
                if delta < self.minFrameInterval {
                    return
                }
            }

            // Accept frame
            self.isProcessing = true
            self.lastFrameTime = time

            self.consumer?.consume(pixelBuffer: pixelBuffer, time: time)
        }
    }

    // MARK: - Completion (called by next layer)
    func frameDidFinish() {
        gateQueue.async {
            self.isProcessing = false
        }
    }
}
