import CoreMedia

final class FramePipeline {

    static let shared = FramePipeline()

    // Используем динамический FPS на основе устройства
    let gate = FrameGate()
    let mlEngine = MLInferenceEngine()

    var renderer: RenderEngine?

    private init() {
        gate.consumer = mlEngine

        mlEngine.onResult = { [weak self] pixelBuffer, time in
            DispatchQueue.main.async {
                self?.renderer?.render(pixelBuffer: pixelBuffer)
            }
        }
        
        print("📱 Device: \(DeviceCapabilities.current.modelName)")
        print("📹 Max FPS: \(DeviceCapabilities.current.maxFPS)")
    }
}
