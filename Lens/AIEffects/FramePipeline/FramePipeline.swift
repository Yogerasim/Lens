import CoreMedia

final class FramePipeline {

    static let shared = FramePipeline()

    // Используем динамический FPS на основе устройства
    let gate = FrameGate()  // внутри берёт DeviceCapabilities.current.maxFPS
    let mlEngine = MLInferenceEngine()

    /// Текущий активный фильтр (меняется из UI)
    var activeFilter: FilterDefinition? = FilterLibrary.shared.filters.first {
        didSet {
            if let filter = activeFilter {
                print("🔄 FramePipeline: Active filter changed to '\(filter.name)' (needsDepth: \(filter.needsDepth))")
            }
        }
    }

    var renderer: RenderEngine?

    private init() {
        gate.consumer = mlEngine

        mlEngine.onResult = { [weak self] pixelBuffer, time in
            guard let self else { return }

            // Берём depth только если фильтр его требует
            let depthPB: CVPixelBuffer?
            if self.activeFilter?.needsDepth == true {
                depthPB = DepthManager.shared.latestDepthPixelBuffer
                if depthPB != nil {
                    // Печатаем только изредка чтобы не спамить
                    if Int(time.seconds * 10) % 50 == 0 {
                        print("🔵 FramePipeline: Depth data available for '\(self.activeFilter?.name ?? "?")'")
                    }
                }
            } else {
                depthPB = nil
            }

            let packet = FramePacket(
                pixelBuffer: pixelBuffer,
                time: time,
                depthPixelBuffer: depthPB
            )

            // ⚠️ Рендер НЕ на main. Пускай Metal отрабатывает на своём потоке.
            self.renderer?.render(packet: packet, activeFilter: self.activeFilter)
        }

        print("📱 Device: \(DeviceCapabilities.current.modelName)")
        print("📹 Max FPS: \(DeviceCapabilities.current.maxFPS)")
        print("🎬 FramePipeline: Initialized with filter '\(activeFilter?.name ?? "none")'")
    }
}
