import CoreMedia
import CoreVideo
import Foundation

protocol FrameConsumer: AnyObject {
  func consume(_ packet: FramePacket)
}

final class FrameGate {

  private let targetFPS: Double
  private let minFrameInterval: CMTime

  private var lastFrameTime: CMTime = .zero
  private var isProcessing = false

  weak var consumer: FrameConsumer?

  private let gateQueue = DispatchQueue(
    label: "frame.gate.queue",
    qos: .userInteractive
  )

  init(targetFPS: Double? = nil) {

    let fps = targetFPS ?? Double(DeviceCapabilities.current.maxFPS)
    self.targetFPS = fps
    self.minFrameInterval = CMTime(
      seconds: 1.0 / fps,
      preferredTimescale: 600
    )
  }

  func push(_ packet: FramePacket) {
    gateQueue.async {

      if self.isProcessing {
        return
      }

      if self.lastFrameTime != .zero {
        let delta = CMTimeSubtract(packet.time, self.lastFrameTime)
        if delta < self.minFrameInterval {
          return
        }
      }

      self.isProcessing = true
      self.lastFrameTime = packet.time

      self.consumer?.consume(packet)
    }
  }

  func frameDidFinish() {
    gateQueue.async {
      self.isProcessing = false
    }
  }
}
