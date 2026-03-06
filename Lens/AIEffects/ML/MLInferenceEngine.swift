import CoreML
import CoreMedia
import CoreVideo

protocol InferenceEngine: FrameConsumer {
  var onResult: ((CVPixelBuffer, CMTime) -> Void)? { get set }
}

final class MLInferenceEngine: InferenceEngine {

  var onResult: ((CVPixelBuffer, CMTime) -> Void)?

  private let inferenceQueue = DispatchQueue(
    label: "ml.inference.queue",
    qos: .userInteractive  // Повышаем приоритет для лучшей производительности
  )

  private let inputSize = CGSize(width: 256, height: 256)

  func consume(_ packet: FramePacket) {
    inferenceQueue.async {
      autoreleasepool {

        self.onResult?(packet.pixelBuffer, packet.time)
        FramePipeline.shared.gate.frameDidFinish()
      }
    }
  }
}
