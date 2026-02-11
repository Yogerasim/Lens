import CoreMedia
import CoreVideo

final class DebugFrameConsumer: FrameConsumer {
    func consume(_ packet: FramePacket) {
        print("🧠 frame passed gate at", packet.time.seconds)

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.01) {
            FramePipeline.shared.gate.frameDidFinish()
        }
    }
}

