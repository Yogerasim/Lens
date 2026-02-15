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
    
    // MARK: - Recording State
    /// Флаг записи — блокирует изменение конфигурации камеры/depth
    @Published var isRecording: Bool = false
    
    /// Hold-last depth buffer для стабильной записи
    /// Хранит последний полученный depth, чтобы не дёргать hasDepth
    private var recordingDepthBuffer: CVPixelBuffer?
    
    /// Стабильный hasDepth флаг для записи (не меняется во время записи)
    private var recordingHasDepth: Bool = false

    /// Текущий активный фильтр (меняется из UI)
    var activeFilter: FilterDefinition? = FilterLibrary.shared.filters.first {
        didSet {
            guard let filter = activeFilter else { return }
            
            // ✅ FIX: Проверяем доступность фильтра для текущей камеры
            let isFront = cameraManager?.isFrontCamera ?? false
            if isFront && filter.needsDepth {
                // Depth фильтр недоступен на фронталке - переключаемся на первый non-depth
                if let fallback = FilterLibrary.shared.firstNonDepthFilter() {
                    print("⛔️ Depth filter '\(filter.name)' selected on front camera -> switching to '\(fallback.name)'")
                    activeFilter = fallback
                    return // didSet вызовется снова с правильным фильтром
                }
            }
            
            print("🎬 FramePipeline: activeFilter -> \(filter.name), needsDepth=\(filter.needsDepth)")
            
            // ⛔️ Блокируем изменение depth policy во время записи
            if isRecording {
                print("⛔️ Ignored depth reconfigure during recording - only shader change allowed")
                // Обновляем только шейдер, но не конфигурацию камеры
                return
            }
            
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
    
    // MARK: - Recording Control
    
    /// Начать запись — фиксирует текущее состояние depth
    func startRecording() {
        isRecording = true
        recordingHasDepth = activeFilter?.needsDepth == true && cameraManager?.isDepthEnabled == true
        recordingDepthBuffer = DepthManager.shared.latestDepthPixelBuffer
        print("🎬 FramePipeline: Recording started, hasDepth=\(recordingHasDepth)")
    }
    
    /// Остановить запись
    func stopRecording() {
        isRecording = false
        recordingDepthBuffer = nil
        print("🎬 FramePipeline: Recording stopped")
    }
    
    /// Обновить hold-last depth buffer (вызывается из DepthManager)
    func updateRecordingDepthBuffer(_ depthBuffer: CVPixelBuffer) {
        if isRecording && recordingHasDepth {
            recordingDepthBuffer = depthBuffer
        }
    }

    var renderer: RenderEngine?

    private init() {
        gate.consumer = mlEngine

        mlEngine.onResult = { [weak self] pixelBuffer, time in
            guard let self else { return }

            // Берём depth buffer
            let depthBuffer: CVPixelBuffer?
            let hasDepthFlag: Bool
            
            if self.isRecording {
                // ✅ FIX: Во время записи используем стабильный hasDepth и hold-last depth
                hasDepthFlag = self.recordingHasDepth
                if hasDepthFlag {
                    // Используем последний известный depth (hold-last)
                    depthBuffer = self.recordingDepthBuffer ?? DepthManager.shared.latestDepthPixelBuffer
                } else {
                    depthBuffer = nil
                }
            } else {
                // Обычный режим превью
                if self.activeFilter?.needsDepth == true && DepthManager.shared.isActive {
                    depthBuffer = DepthManager.shared.latestDepthPixelBuffer
                    hasDepthFlag = depthBuffer != nil
                } else {
                    depthBuffer = nil
                    hasDepthFlag = false
                }
            }

            let packet = FramePacket(
                pixelBuffer: pixelBuffer,
                time: time,
                depthPixelBuffer: depthBuffer
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
