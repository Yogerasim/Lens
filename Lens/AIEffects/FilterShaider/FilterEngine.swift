import Combine
import CoreMedia
import CoreVideo

final class FilterEngine: FrameConsumer {

  var onResult: ((FramePacket) -> Void)?

  @Published var activeFilter: FilterDefinition

  init(active: FilterDefinition) {
    self.activeFilter = active
  }

  func setFilter(_ filter: FilterDefinition) {
    self.activeFilter = filter
  }

  func consume(_ packet: FramePacket) {

    onResult?(packet)
    FramePipeline.shared.gate.frameDidFinish()
  }
}
