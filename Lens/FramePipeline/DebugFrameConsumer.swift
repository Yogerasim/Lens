import CoreMedia

final class DebugFrameConsumer: FrameConsumer {
    func consume(pixelBuffer: CVPixelBuffer, time: CMTime) {
        print("🧠 frame passed gate at", time.seconds)

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.01) {
            FramePipeline.shared.gate.frameDidFinish()
        }
    }
}

