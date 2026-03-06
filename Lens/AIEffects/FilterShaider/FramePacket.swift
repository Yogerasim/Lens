import CoreMedia
import CoreVideo

struct FramePacket {
  let pixelBuffer: CVPixelBuffer
  let time: CMTime
  let depthPixelBuffer: CVPixelBuffer?
}
