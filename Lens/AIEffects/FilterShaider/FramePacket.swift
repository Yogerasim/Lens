
import CoreVideo
import CoreMedia

struct FramePacket {
    let pixelBuffer: CVPixelBuffer
    let time: CMTime
    let depthPixelBuffer: CVPixelBuffer?
}
