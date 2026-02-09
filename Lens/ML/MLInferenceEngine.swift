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
    func consume(pixelBuffer: CVPixelBuffer, time: CMTime) {
        inferenceQueue.async {
            autoreleasepool {
                // Passthrough — берём кадр камеры
                self.onResult?(pixelBuffer, time)
                FramePipeline.shared.gate.frameDidFinish()
            }
        }
    }
}
