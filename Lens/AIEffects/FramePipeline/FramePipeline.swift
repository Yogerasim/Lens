import CoreMedia
import Combine
internal import AVFoundation

final class FramePipeline: ObservableObject {

    static let shared = FramePipeline()

    // Используем динамический FPS на основе устройства
    let gate = FrameGate()  // внутри берёт DeviceCapabilities.current.maxFPS
    let mlEngine = MLInferenceEngine()
    
    /// Ссылка на CameraManager для управления depth
    weak var cameraManager: CameraManager?
    
    /// Флаг для UI: depth режим активен (фронтальная камера недоступна)
    @Published private(set) var isDepthModeActive: Bool = false

    /// Текущий активный фильтр (меняется из UI)
    var activeFilter: FilterDefinition? = FilterLibrary.shared.filters.first {
        didSet {
            if let filter = activeFilter {
                print("🎬 FramePipeline: activeFilter -> \(filter.name), needsDepth=\(filter.needsDepth)")
                
                // Вызываем централизованный метод управления depth в CameraManager
                guard let camera = cameraManager else {
                    print("⚠️ FramePipeline: No cameraManager reference for depth control")
                    return
                }
                
                camera.applyDepthPolicy(needsDepth: filter.needsDepth, reason: "activeFilter changed to \(filter.name)")
                
                // Обновляем флаг для UI
                updateDepthModeActive()
            }
        }
    }
    
    /// Обновить флаг isDepthModeActive на main thread
    func updateDepthModeActive() {
        let newValue = activeFilter?.needsDepth == true || (cameraManager?.isDepthEnabled == true)
        if newValue != isDepthModeActive {
            DispatchQueue.main.async {
                self.isDepthModeActive = newValue
                print("🧭 UI depthModeActive = \(newValue)")
            }
        }
    }

    var renderer: RenderEngine?

    private init() {
        gate.consumer = mlEngine

        mlEngine.onResult = { [weak self] pixelBuffer, time in
            guard let self else { return }

            // Берём depth только если фильтр его требует И depth активен
            let depthPB: CVPixelBuffer?
            if self.activeFilter?.needsDepth == true && DepthManager.shared.isActive {
                depthPB = DepthManager.shared.latestDepthPixelBuffer
            } else {
                depthPB = nil
            }

            let packet = FramePacket(
                pixelBuffer: pixelBuffer,
                time: time,
                depthPixelBuffer: depthPB
            )

            // Рендер на своём потоке
            self.renderer?.render(packet: packet, activeFilter: self.activeFilter)
        }

        print("📱 Device: \(DeviceCapabilities.current.modelName)")
        print("📹 Max FPS: \(DeviceCapabilities.current.maxFPS)")
        print("🎬 FramePipeline: Initialized with filter '\(activeFilter?.name ?? "none")'")
    }
    
    /// Метод для обновления activeFilter из ShaderManager
    func setActiveFilter(by shaderName: String) {
        if let filter = FilterLibrary.shared.filter(for: shaderName) {
            activeFilter = filter // это вызовет didSet и applyDepthPolicy в CameraManager
        }
    }
}

