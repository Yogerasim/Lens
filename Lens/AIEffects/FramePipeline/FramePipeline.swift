import CoreMedia
import Combine
import QuartzCore
import UIKit
internal import AVFoundation

// MARK: - Filter Family (для блокировки при записи)
enum FilterFamily: String {
    case depth = "DEPTH"
    case nonDepth = "NON-DEPTH"
}

final class FramePipeline: ObservableObject {

    static let shared = FramePipeline()

    // Используем динамический FPS на основе устройства
    let gate = FrameGate()  // внутри берёт DeviceCapabilities.current.maxFPS
    let mlEngine = MLInferenceEngine()
    
    /// Ссылка на CameraManager для управления depth
    weak var cameraManager: CameraManager?
    
    /// Флаг для UI: depth режим активен (фронтальная камера недоступна)
    @Published private(set) var isDepthModeActive: Bool = false
    
    // MARK: - Orientation Management for iPad
    /// Текущий угол поворота интерфейса (в радианах) для Metal uniforms
    @Published var interfaceRotation: Float = 0.0
    
    /// Cancellable для подписки на изменения ориентации
    private var orientationCancellable: AnyCancellable?
    
    // MARK: - Recording State
    /// Флаг записи — блокирует изменение конфигурации камеры/depth
    @Published var isRecording: Bool = false
    
    /// Семейство фильтров, заблокированное при записи
    /// Устанавливается в момент startRecording
    private(set) var recordingFilterFamily: FilterFamily? = nil
    
    /// Hold-last depth buffer для стабильной записи
    /// Хранит последний полученный depth, чтобы не дёргать hasDepth
    private var recordingDepthBuffer: CVPixelBuffer?
    
    /// Стабильный hasDepth флаг для записи (не меняется во время записи)
    private var recordingHasDepth: Bool = false
    
    // MARK: - Effect Intensity (Smoothed)
    /// Целевая сила эффекта (мгновенная цель из жеста)
    @Published private(set) var targetIntensity: Float = 1.0
    
    /// Сглаженная сила эффекта (реально идёт в Metal и UI)
    @Published private(set) var smoothedIntensity: Float = 1.0
    
    /// Коэффициент сглаживания (0.1-0.2 = плавно, 0.5+ = быстро)
    private let smoothingAlpha: Float = 0.15
    
    /// DisplayLink для плавного обновления intensity
    private var displayLink: CADisplayLink?
    
    /// Throttle для логов intensity
    private var lastIntensityLogTime: CFTimeInterval = 0
    private let intensityLogInterval: CFTimeInterval = 0.1
    
    /// Поддерживает ли текущий фильтр intensity
    var currentFilterSupportsIntensity: Bool {
        activeFilter?.supportsIntensity ?? true
    }

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
            
            // ✅ FIX: Проверяем блокировку по семейству фильтров при записи
            if isRecording, let family = recordingFilterFamily {
                let filterFamily: FilterFamily = filter.needsDepth ? .depth : .nonDepth
                if filterFamily != family {
                    print("⛔️ Filter '\(filter.name)' blocked during recording (locked to \(family.rawValue) filters)")
                    // Откатываемся на предыдущий допустимый фильтр
                    if let fallback = FilterLibrary.shared.filters.first(where: {
                        ($0.needsDepth && family == .depth) || (!$0.needsDepth && family == .nonDepth)
                    }) {
                        activeFilter = fallback
                    }
                    return
                }
            }
            
            print("🎬 FramePipeline: activeFilter -> \(filter.name), needsDepth=\(filter.needsDepth)")
            print("🎛️ Filter '\(filter.name)' needsDepth=\(filter.needsDepth) supportsIntensity=\(filter.supportsIntensity)")
            
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
    
    // MARK: - Effect Intensity Control
    
    /// Установить целевую intensity (жест вызывает этот метод)
    func setTargetIntensity(_ value: Float, reason: String = "") {
        let clamped = max(0.0, min(1.0, value))
        targetIntensity = clamped
        
        // Запускаем smoothing если ещё не запущен
        startSmoothingLoopIfNeeded()
    }
    
    /// Запускает DisplayLink для плавного обновления
    private func startSmoothingLoopIfNeeded() {
        guard displayLink == nil else { return }
        
        displayLink = CADisplayLink(target: self, selector: #selector(updateSmoothedIntensity))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120)
        displayLink?.add(to: .main, forMode: .common)
    }
    
    /// Останавливает DisplayLink когда intensity стабилизировалась
    private func stopSmoothingLoop() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    /// Вызывается на каждом кадре DisplayLink
    @objc private func updateSmoothedIntensity() {
        let diff = targetIntensity - smoothedIntensity
        
        // Если достаточно близко — останавливаем
        if abs(diff) < 0.001 {
            smoothedIntensity = targetIntensity
            stopSmoothingLoop()
            return
        }
        
        // Плавное приближение к цели
        smoothedIntensity += diff * smoothingAlpha
        
        // Throttled logging
        let now = CACurrentMediaTime()
        if now - lastIntensityLogTime > intensityLogInterval {
            lastIntensityLogTime = now
            print("🎚️ target=\(String(format: "%.2f", targetIntensity)) smooth=\(String(format: "%.2f", smoothedIntensity))")
        }
    }
    
    /// Устаревший метод для совместимости (перенаправляет на setTargetIntensity)
    func setEffectIntensity(_ value: Float) {
        setTargetIntensity(value, reason: "legacy call")
    }
    
    /// Intensity для Metal (учитывает supportsIntensity фильтра)
    var effectIntensityForMetal: Float {
        guard currentFilterSupportsIntensity else {
            return 1.0 // Если фильтр не поддерживает — всегда полный эффект
        }
        return smoothedIntensity
    }
    
    // MARK: - Recording Control
    
    /// Начать запись — фиксирует текущее состояние depth и семейство фильтров
    func startRecording() {
        isRecording = true
        recordingHasDepth = activeFilter?.needsDepth == true && cameraManager?.isDepthEnabled == true
        recordingDepthBuffer = DepthManager.shared.latestDepthPixelBuffer
        
        // ✅ FIX: Устанавливаем семейство фильтров для блокировки
        recordingFilterFamily = (activeFilter?.needsDepth == true) ? .depth : .nonDepth
        
        print("🎬 FramePipeline: Recording started, hasDepth=\(recordingHasDepth)")
        print("🎥 Recording locked to \(recordingFilterFamily?.rawValue ?? "UNKNOWN") filters")
    }
    
    /// Остановить запись
    func stopRecording() {
        isRecording = false
        recordingDepthBuffer = nil
        recordingFilterFamily = nil
        print("🎬 FramePipeline: Recording stopped, filter lock released")
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
        
        // MARK: - Orientation Management for iPad
        // Подписываемся на изменения ориентации из OrientationManager
        orientationCancellable = OrientationManager.shared.$rotationAngle
            .sink { [weak self] newRotation in
                self?.interfaceRotation = newRotation
                let degrees = Int(newRotation * 180 / .pi)
                print("🧭 FramePipeline: interfaceRotation updated = \(degrees)°")
            }
    }
    
    /// Метод для обновления activeFilter из ShaderManager
    func setActiveFilter(by shaderName: String) {
        if let filter = FilterLibrary.shared.filter(for: shaderName) {
            activeFilter = filter // это вызовет didSet и applyDepthPolicy в CameraManager
        }
    }
}
