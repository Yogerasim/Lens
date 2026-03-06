import CoreMedia
import CoreVideo

struct FramePacket {
  let pixelBuffer: CVPixelBuffer
  let time: CMTime
  let depthPixelBuffer: CVPixelBuffer?

  init(pixelBuffer: CVPixelBuffer, time: CMTime, depthPixelBuffer: CVPixelBuffer? = nil) {
    self.pixelBuffer = pixelBuffer
    self.time = time
    self.depthPixelBuffer = depthPixelBuffer
  }
}
