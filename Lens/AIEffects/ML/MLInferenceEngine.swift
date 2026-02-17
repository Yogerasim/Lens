import CoreML
import CoreVideo
import CoreMedia

protocol InferenceEngine: FrameConsumer {
    var onResult: ((CVPixelBuffer, CMTime) -> Void)? { get set }
}

final class MLInferenceEngine: InferenceEngine {
    
    // MARK: - Output
    var onResult: ((CVPixelBuffer, CMTime) -> Void)?
    
    // MARK: - Private
    private let inferenceQueue = DispatchQueue(
        label: "ml.inference.queue",
        qos: .userInteractive  // Повышаем приоритет для лучшей производительности
    )
    
    private let inputSize = CGSize(width: 256, height: 256)
    
    // MARK: - Consume frame
    func consume(_ packet: FramePacket) {
        inferenceQueue.async {
            autoreleasepool {
                // Passthrough — берём кадр камеры
                self.onResult?(packet.pixelBuffer, packet.time)
                FramePipeline.shared.gate.frameDidFinish()
            }
        }
    }
}
