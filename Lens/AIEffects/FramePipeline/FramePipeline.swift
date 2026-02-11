import CoreMedia

final class FramePipeline {

    static let shared = FramePipeline()

    // Используем динамический FPS на основе устройства
    let gate = FrameGate(targetFPS: 120)
    let mlEngine = MLInferenceEngine()
    
    /// Текущий активный фильтр
    var activeFilter: FilterDefinition? = FilterLibrary.shared.filters.first

    var renderer: RenderEngine?

    private init() {
        gate.consumer = mlEngine

        mlEngine.onResult = { [weak self] pixelBuffer, time in
            DispatchQueue.main.async {
                let packet = FramePacket(pixelBuffer: pixelBuffer, time: time)
                self?.renderer?.render(packet: packet, activeFilter: self?.activeFilter)
            }
        }
        
        print("📱 Device: \(DeviceCapabilities.current.modelName)")
        print("📹 Max FPS: \(DeviceCapabilities.current.maxFPS)")
    }
}
