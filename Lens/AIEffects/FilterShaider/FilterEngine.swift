import CoreMedia
import CoreVideo
import Combine

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
        // Пока мы НЕ меняем пиксельбуфер через ML
        // Просто пробрасываем, а shader выбираем на рендере
        onResult?(packet)
        FramePipeline.shared.gate.frameDidFinish()
    }
}
