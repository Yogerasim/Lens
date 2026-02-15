internal import AVFoundation
import CoreVideo
import Combine

final class CameraManager: NSObject, ObservableObject {
    
    // MARK: - Public
    let session = AVCaptureSession()
    
    
    
    /// Замыкание для получения кадра
    var onFrame: ((CVPixelBuffer, CMTime) -> Void)?
    
    /// Замыкание для получения аудио сэмплов
    var onAudioSample: ((CMSampleBuffer) -> Void)?
    
    /// Текущая позиция камеры
    @Published var currentPosition: AVCaptureDevice.Position = .back
    
    /// Информация для правильной ориентации
    var isFrontCamera: Bool {
        return currentPosition == .front
    }
    
    /// Поворот для портретного режима
    /// Back camera: π/2 (90°), Front camera: -π/2 (-90°)
    var rotation: Float {
        if currentPosition == .front {
            return -Float.pi / 2.0  // -90 градусов для фронталки
        } else {
            return Float.pi / 2.0   // 90 градусов для задней
        }
    }
    
    /// Текущий зум фактор
    @Published var currentZoomFactor: CGFloat = 1.0
    
    /// Статус depth (включён/выключен)
    @Published var isDepthEnabled: Bool = false
    
    /// Минимальный зум (динамически обновляется от устройства)
    private var minZoomFactor: CGFloat = 1.0
    
    /// Максимальный зум (динамически обновляется от устройства)
    private var maxZoomFactor: CGFloat = 10.0
    
    // MARK: - Private
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let outputQueue = DispatchQueue(label: "camera.output.queue")
    private let audioOutputQueue = DispatchQueue(label: "camera.audio.queue")
    nonisolated(unsafe) private let videoOutput = AVCaptureVideoDataOutput()
    nonisolated(unsafe) private let audioOutput = AVCaptureAudioDataOutput()
    private(set) var currentInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    
    // Текущий тип камеры (для back)
    private var currentBackDeviceType: AVCaptureDevice.DeviceType = .builtInWideAngleCamera
    
    // MARK: - Init
    override init() {
        super.init()
        configureSession()
    }
    
    // MARK: - Session Configuration
    private func configureSession() {
        sessionQueue.async {
            self.session.beginConfiguration()
            
            // Используем inputPriority чтобы вручную выбирать формат с depth
            self.session.sessionPreset = .inputPriority
            
            print("🔵 CameraManager: Configuring session at startup")
            print("   ℹ️ LiDAR will be enabled on demand when depth filter is selected")
            
            // Настраиваем video и audio outputs
            self.configureOutputs()
            
            // При старте ВСЕГДА используем обычную Wide камеру без depth
            let desiredTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera]
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: desiredTypes,
                mediaType: .video,
                position: self.currentPosition
            )
            
            if let videoDevice = discovery.devices.first(where: { $0.deviceType == .builtInWideAngleCamera }) ?? discovery.devices.first {
                // Используем универсальный метод конфигурации без depth
                self.configureCamera(device: videoDevice, enableDepth: false)
                
                print("🔵 CameraManager: Depth will be enabled on demand (when depth filter selected)")
            } else {
                print("❌ No video device found")
            }
            
            self.session.commitConfiguration()
        }
    }
    
    /// Настраиваем video и audio outputs
    private func configureOutputs() {
        // Audio input (try add; if permission denied later, session will still run)
        if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
            if let mic = AVCaptureDevice.default(for: .audio) {
                do {
                    let inAudio = try AVCaptureDeviceInput(device: mic)
                    if self.session.canAddInput(inAudio) {
                        self.session.addInput(inAudio)
                        self.audioInput = inAudio
                    }
                } catch {
                    print("⚠️ Failed to create audio input: \(error)")
                }
            }
        }
        
        // Video output settings
        self.videoOutput.alwaysDiscardsLateVideoFrames = true
        // BGRA is convenient for CI/Metal path you use
        self.videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        self.videoOutput.setSampleBufferDelegate(self, queue: self.outputQueue)
        if self.session.canAddOutput(self.videoOutput) {
            self.session.addOutput(self.videoOutput)
        }
        
        // Audio output
        self.audioOutput.setSampleBufferDelegate(self, queue: self.audioOutputQueue)
        if self.session.canAddOutput(self.audioOutput) {
            self.session.addOutput(self.audioOutput)
        }
    }
    
    // MARK: - Start/Stop
    func start() {
        // Сначала проверяем/запрашиваем разрешение на камеру
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            requestAudioPermissionAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.requestAudioPermissionAndStart()
                } else {
                    print("❌ Camera access denied")
                }
            }
        default:
            print("❌ Camera access denied or restricted")
        }
    }
    
    private func requestAudioPermissionAndStart() {
        // Запрашиваем разрешение на микрофон
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                // Запускаем даже если микрофон запрещён (просто без звука)
                self.startSession()
            }
        default:
            // Запускаем без микрофона
            startSession()
        }
    }
    
    private func startSession() {
        sessionQueue.async {
            if !self.session.isRunning {
                self.session.startRunning()
                if let device = self.currentInput?.device {
                    self.updateZoomLimits(for: device)
                }
                print("✅ Camera session started")
            }
        }
    }
    
    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }
    
    // MARK: - Depth Control
    func enableDepth() {
        sessionQueue.async {
            guard !DepthManager.shared.isActive else {
                print("🔵 CameraManager: Depth already active")
                return
            }
            
            guard self.currentPosition == .back else {
                print("⚠️ CameraManager: Depth only available on back camera")
                return
            }
            
            // Depth включен через новую архитектуру (setDepthEnabled -> configureCamera)
            print("ℹ️ CameraManager: Use setDepthEnabled method instead of enableDepth")
            print("✅ CameraManager: Depth enabled")
        }
    }
    
    func disableDepth() {
        sessionQueue.async {
            guard DepthManager.shared.isActive else {
                print("🔵 CameraManager: Depth already inactive")
                return
            }
            
            self.session.beginConfiguration()
            DepthManager.shared.removeDepthOutput(from: self.session)
            self.session.commitConfiguration()
            
            print("✅ CameraManager: Depth disabled")
        }
    }
    
    // MARK: - Switch Camera
    func switchCamera() {
        // ⛔️ Блокируем переключение камеры во время записи
        if FramePipeline.shared.isRecording {
            print("⛔️ CameraManager: Camera switch blocked during recording")
            return
        }
        
        // Блокируем переключение на фронтальную камеру в depth режиме
        if isDepthEnabled && currentPosition == .back {
            print("🚫 CameraManager: Front camera blocked in depth mode")
            return
        }
        
        sessionQueue.async {
            let newPosition: AVCaptureDevice.Position = self.currentPosition == .back ? .front : .back
            
            // Дополнительная проверка на sessionQueue
            if self.isDepthEnabled && newPosition == .front {
                print("🚫 CameraManager: Front camera blocked in depth mode (sessionQueue)")
                return
            }
            
            self.switchToDevice(type: .builtInWideAngleCamera, position: newPosition)
        }
    }
    
    // MARK: - Internal helpers
    private func switchToDevice(type: AVCaptureDevice.DeviceType, position: AVCaptureDevice.Position) {
        print("📸 CameraManager: Switching to \(type) at \(position == .back ? "BACK" : "FRONT")")
        
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInUltraWideCamera, .builtInWideAngleCamera, .builtInTelephotoCamera],
            mediaType: .video,
            position: position
        )
        guard let device = discovery.devices.first(where: { $0.deviceType == type }) ?? discovery.devices.first else {
            print("❌ CameraManager: No device for type: \(type) position: \(position)")
            return
        }
        
        do {
            // Обновляем позицию камеры
            self.currentPosition = position
            if position == .back {
                self.currentBackDeviceType = device.deviceType
            }
            
            // Логируем обновление rotation
            let newRotation = (position == .front) ? -Float.pi / 2.0 : Float.pi / 2.0
            print("🧭 CameraManager: rotation updated = \(newRotation) (\(Int(newRotation * 180 / .pi))°), mirrored=\(position == .front)")
            
            // Определяем нужен ли depth для текущего фильтра
            let needsDepth = FramePipeline.shared.activeFilter?.needsDepth ?? false
            let enableDepth = position == .back && type == .builtInWideAngleCamera && needsDepth
            
            if enableDepth {
                print("🟢 CameraManager: Enabling depth (back x1 + depth filter)")
            } else {
                print("⚪ CameraManager: Depth not enabled (filter doesn't need it or wrong camera)")
            }
            
            // Используем универсальный метод конфигурации
            // (он сам управляет beginConfiguration/commitConfiguration)
            session.beginConfiguration()
            
            // Удаляем depth output если меняем камеру
            print("🔴 CameraManager: Removing depth output before switch")
            DepthManager.shared.removeDepthOutput(from: session)
            
            // Настраиваем новую камеру с правильными параметрами
            configureCamera(device: device, enableDepth: enableDepth)
            
            session.commitConfiguration()
            
            updateZoomLimits(for: device)
            print("✅ CameraManager: Switched to \(device.localizedName)")
            setZoom(1.0) // Сбросить на оптический базовый зум
            
        } catch {
            print("❌ switchToDevice error: \(error)")
        }
    }
    
    private func updateZoomLimits(for device: AVCaptureDevice) {
        if #available(iOS 17.0, *) {
            self.minZoomFactor = max(1.0, device.minAvailableVideoZoomFactor)
        } else {
            self.minZoomFactor = 1.0
        }
        self.maxZoomFactor = min(10.0, device.activeFormat.videoMaxZoomFactor)
        DispatchQueue.main.async { self.currentZoomFactor = max(self.currentZoomFactor, self.minZoomFactor) }
    }
    
    /// Универсальный метод конфигурации камеры (для обычного режима и depth)
    private func configureCamera(device: AVCaptureDevice, enableDepth: Bool) {
        print("📷 Configuring camera:")
        print("   📷 Active device: \(device.deviceType.rawValue)")
        print("   📊 Depth enabled: \(enableDepth)")
        
        // 1. Удаляем старый input
        if let existing = currentInput {
            session.removeInput(existing)
        }
        
        // 2. Создаём и добавляем новый input
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                print("❌ CameraManager: Cannot add device input")
                return
            }
            session.addInput(input)
            currentInput = input
            
            if currentPosition == .back {
                currentBackDeviceType = device.deviceType
            }
        } catch {
            print("❌ CameraManager: Failed to create device input: \(error)")
            return
        }
        
        // 3. Выбираем формат (с поддержкой depth если нужно)
        var selectedFormat: AVCaptureDevice.Format?
        
        if enableDepth {
            print("🔍 Looking for depth format on Wide camera...")
            
            // Сначала ищем depth-форматы
            let depthFormats = device.formats.filter { !$0.supportedDepthDataFormats.isEmpty }
            print("   Found \(depthFormats.count) formats with depth support")
            
            // Предпочтительные разрешения в порядке приоритета
            let preferredWidths: [Int32] = [1920, 1280] // 1920x1080, 1280x720
            
            // Ищем среди предпочтительных разрешений
            for preferredWidth in preferredWidths {
                selectedFormat = depthFormats.first { format in
                    let dim = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                    return dim.width == preferredWidth
                }
                if selectedFormat != nil {
                    let dim = CMVideoFormatDescriptionGetDimensions(selectedFormat!.formatDescription)
                    print("   📐 Selected preferred format: \(dim.width)x\(dim.height), depth formats: \(selectedFormat!.supportedDepthDataFormats.count)")
                    break
                }
            }
            
            // Если не нашли предпочтительное - берем лучший по разрешению
            if selectedFormat == nil && !depthFormats.isEmpty {
                selectedFormat = depthFormats.max { format1, format2 in
                    let dim1 = CMVideoFormatDescriptionGetDimensions(format1.formatDescription)
                    let dim2 = CMVideoFormatDescriptionGetDimensions(format2.formatDescription)
                    return dim1.width * dim1.height < dim2.width * dim2.height
                }
                
                if let format = selectedFormat {
                    let dim = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                    print("   📐 Selected best available format: \(dim.width)x\(dim.height), depth formats: \(format.supportedDepthDataFormats.count)")
                }
            }
            
            if selectedFormat == nil {
                print("❌ CameraManager: No depth-compatible format found")
                return
            } else {
                print("✅ Selected depth format successfully")
            }
        } else {
            // Для обычного режима используем лучший доступный формат
            selectedFormat = findBestFormat(for: device)
        }
        
        // 4. Устанавливаем формат и FPS
        if let format = selectedFormat {
            configureFormat(device: device, format: format)
        }
        
        // 5. Настраиваем video connection (одинаково для обычного и depth режима)
        configureVideoConnection()
        
        // 6. Настраиваем depth если нужно
        if enableDepth {
            DepthManager.shared.setupDepthOutput(for: session)
            synchronizeDepthOrientation()
            print("✅ CameraManager: Depth output configured")
        } else {
            DepthManager.shared.removeDepthOutput(from: session)
            print("✅ CameraManager: Depth output removed")
        }
        
        // 7. Обновляем zoom limits
        updateZoomLimits(for: device)
        
        print("✅ CameraManager: Camera configured successfully")
    }
    
    /// Находит лучший формат для устройства (без depth)
    private func findBestFormat(for device: AVCaptureDevice) -> AVCaptureDevice.Format? {
        let targetFPS = Double(DeviceCapabilities.current.maxFPS)
        
        var bestFormat: AVCaptureDevice.Format?
        
        for format in device.formats {
            // Проверяем поддержку целевого FPS
            let supportsTargetFPS = format.videoSupportedFrameRateRanges.contains { range in
                range.maxFrameRate >= targetFPS
            }
            
            if supportsTargetFPS {
                // Предпочитаем формат с более высоким разрешением
                if bestFormat == nil {
                    bestFormat = format
                } else {
                    let currentDim = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                    let bestDim = CMVideoFormatDescriptionGetDimensions(bestFormat!.formatDescription)
                    if currentDim.width * currentDim.height > bestDim.width * bestDim.height {
                        bestFormat = format
                    }
                }
            }
        }
        
        return bestFormat ?? device.activeFormat
    }
    
    /// Конфигурирует формат и FPS для устройства
    private func configureFormat(device: AVCaptureDevice, format: AVCaptureDevice.Format) {
        let targetFPS = Double(DeviceCapabilities.current.maxFPS)
        
        // Ищем подходящий frame rate range
        var bestFrameRateRange: AVFrameRateRange?
        for range in format.videoSupportedFrameRateRanges {
            if range.maxFrameRate >= targetFPS {
                bestFrameRateRange = range
                break
            }
        }
        
        guard let frameRateRange = bestFrameRateRange else {
            print("⚠️ CameraManager: Format doesn't support \(targetFPS) FPS")
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            // Устанавливаем формат
            if device.activeFormat != format {
                device.activeFormat = format
            }
            
            // Устанавливаем frame rate
            let frameDuration = CMTime(value: 1, timescale: CMTimeScale(targetFPS))
            device.activeVideoMinFrameDuration = frameDuration
            device.activeVideoMaxFrameDuration = frameDuration
            
            device.unlockForConfiguration()
            
            let dim = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            print("📐 Active format: \(dim.width)x\(dim.height) @ \(Int(targetFPS))fps")
            
            // Проверяем поддержку depth
            let depthSupported = !format.supportedDepthDataFormats.isEmpty
            print("📊 Format supports depth: \(depthSupported ? "YES" : "NO")")
            
        } catch {
            print("❌ CameraManager: Failed to configure format: \(error)")
        }
    }
    
    /// Конфигурирует video connection (одинаково для всех режимов)
    private func configureVideoConnection() {
        guard let connection = videoOutput.connection(with: .video) else {
            print("⚠️ CameraManager: No video connection found")
            return
        }
        
        if #available(iOS 17.0, *) {
            connection.videoRotationAngle = 0 // не вращаем буфер, поворот в шейдере
        } else {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait // влияет на метаданные, не на буфер
            }
        }
        
        // Mirror только для фронтальной камеры (но мы делаем это в шейдере)
        if connection.isVideoMirroringSupported {
            connection.isVideoMirrored = false
        }
        
        print("✅ CameraManager: Video connection configured")
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate & AVCaptureAudioDataOutputSampleBufferDelegate
nonisolated extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        if output == videoOutput {
            // Video
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            onFrame?(pixelBuffer, time)
        } else if output == audioOutput {
            // Audio
            onAudioSample?(sampleBuffer)
        }
    }
}

// MARK: - Zoom Control
extension CameraManager {
    func setZoom(_ factor: CGFloat) {
        sessionQueue.async {
            guard let device = self.currentInput?.device else { return }
            let hardwareMax = device.activeFormat.videoMaxZoomFactor
            let clampedZoom = max(self.minZoomFactor, min(factor, min(self.maxZoomFactor, hardwareMax)))
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clampedZoom
                device.unlockForConfiguration()
                DispatchQueue.main.async { self.currentZoomFactor = clampedZoom }
            } catch {
                print("❌ Failed to set zoom: \(error)")
            }
        }
    }
    
    func zoom(to preset: ZoomPreset) {
        // Блокируем зум если depth включён и пытаемся переключиться не на 1x
        if isDepthEnabled && preset != .wide {
            print("🚫 Zoom preset blocked because depth is enabled - only 1x allowed")
            return
        }
        
        sessionQueue.async {
            // Подбираем оптимальную камеру под пресет
            switch preset {
            case .ultraWide:
                // Доступно только на back
                guard self.currentPosition == .back else {
                    DispatchQueue.main.async { self.setZoom(1.0) }
                    return
                }
                self.switchToDevice(type: .builtInUltraWideCamera, position: .back)
            case .wide:
                self.switchToDevice(type: .builtInWideAngleCamera, position: self.currentPosition)
            case .telephoto:
                if self.currentPosition == .back {
                    // Пытаемся включить телекамеру, иначе цифровой 2x на широкоугольной
                    let discovery = AVCaptureDevice.DiscoverySession(
                        deviceTypes: [.builtInTelephotoCamera],
                        mediaType: .video,
                        position: .back
                    )
                    if discovery.devices.isEmpty {
                        // Нет телекамеры — цифровой зум на широкоугольной
                        self.switchToDevice(type: .builtInWideAngleCamera, position: .back)
                        self.setZoom(2.0)
                    } else {
                        self.switchToDevice(type: .builtInTelephotoCamera, position: .back)
                    }
                } else {
                    // На фронталке телекамеры нет — цифровой зум 2x
                    self.setZoom(2.0)
                }
            }
        }
    }
    
    // MARK: - Depth Management
    /// Централизованный метод управления depth политикой
    func applyDepthPolicy(needsDepth: Bool, reason: String) {
        print("🎯 CameraManager: applyDepthPolicy(needsDepth: \(needsDepth)) - \(reason)")
        
        // ⛔️ Блокируем изменение depth policy во время записи
        if FramePipeline.shared.isRecording {
            print("⛔️ CameraManager: Depth policy change blocked during recording")
            return
        }
        
        // Depth работает только на back camera
        let canUseDepth = currentPosition == .back
        
        if needsDepth && canUseDepth {
            print("🟢 CameraManager: Filter needs depth and we're on back camera")
            setDepthEnabled(true, reason: reason)
        } else if needsDepth && !canUseDepth {
            print("❌ CameraManager: Filter needs depth but we're on front camera - depth disabled")
            setDepthEnabled(false, reason: "Front camera doesn't support depth")
        } else {
            print("⚪️ CameraManager: Filter doesn't need depth - disabling")
            setDepthEnabled(false, reason: reason)
        }
    }
    
    /// Включает/выключает depth динамически в зависимости от выбранного фильтра
    private func setDepthEnabled(_ enabled: Bool, reason: String) {
        print("🔵 CameraManager: setDepthEnabled(\(enabled)) - \(reason)")
        
        // Идемпотентность — если состояние не изменилось, ничего не делаем
        guard enabled != isDepthEnabled else {
            print("   ↪️ Depth already \(enabled ? "enabled" : "disabled"), skipping")
            return
        }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            defer { self.session.commitConfiguration() }
            
            if enabled {
                print("🟢 CameraManager: ENABLING depth - looking for LiDAR camera")
                
                // На iPhone 14 Pro используем builtInLiDARDepthCamera
                let lidarDiscovery = AVCaptureDevice.DiscoverySession(
                    deviceTypes: [.builtInLiDARDepthCamera],
                    mediaType: .video,
                    position: .back
                )
                
                if let lidarDevice = lidarDiscovery.devices.first {
                    print("✅ CameraManager: Found LiDAR camera - \(lidarDevice.localizedName)")
                    self.configureCamera(device: lidarDevice, enableDepth: true)
                    
                    // Обновляем флаг на main thread
                    DispatchQueue.main.async {
                        self.isDepthEnabled = true
                        print("📱 CameraManager: UI updated - isDepthEnabled = true")
                    }
                } else {
                    // Fallback: пробуем найти Wide камеру с depth support
                    print("⚠️ CameraManager: No LiDAR camera, trying Wide camera with depth formats")
                    
                    let wideDiscovery = AVCaptureDevice.DiscoverySession(
                        deviceTypes: [.builtInWideAngleCamera],
                        mediaType: .video,
                        position: .back
                    )
                    
                    if let wideDevice = wideDiscovery.devices.first {
                        let hasDepthFormats = wideDevice.formats.contains { !$0.supportedDepthDataFormats.isEmpty }
                        if hasDepthFormats {
                            print("✅ CameraManager: Wide camera has depth formats")
                            self.configureCamera(device: wideDevice, enableDepth: true)
                            
                            DispatchQueue.main.async {
                                self.isDepthEnabled = true
                                print("📱 CameraManager: UI updated - isDepthEnabled = true")
                            }
                        } else {
                            print("❌ CameraManager: No depth support available on this device")
                        }
                    }
                }
            } else {
                print("⚪️ CameraManager: DISABLING depth - switching to Wide camera")
                
                // Находим Wide камеру для отключения depth
                let wideDiscovery = AVCaptureDevice.DiscoverySession(
                    deviceTypes: [.builtInWideAngleCamera],
                    mediaType: .video,
                    position: .back
                )
                
                if let wideDevice = wideDiscovery.devices.first {
                    self.configureCamera(device: wideDevice, enableDepth: false)
                    print("✅ CameraManager: Depth DISABLED")
                }
                
                // Обновляем флаг на main thread
                DispatchQueue.main.async {
                    self.isDepthEnabled = false
                    print("📱 CameraManager: UI updated - isDepthEnabled = false")
                }
            }
        }
    }
    
    /// Синхронизирует orientation для video и depth outputs
    private func synchronizeDepthOrientation() {
        guard let videoConnection = videoOutput.connection(with: .video),
              let depthOutput = DepthManager.shared.depthOutput,
              let depthConnection = depthOutput.connection(with: .depthData) else {
            print("⚠️ CameraManager: Cannot synchronize - missing connections")
            return
        }
        
        // Устанавливаем одинаковые параметры
        let orientation: AVCaptureVideoOrientation = .portrait
        let shouldMirror = currentPosition == .front
        
        // Video connection
        if videoConnection.isVideoOrientationSupported {
            videoConnection.videoOrientation = orientation
        }
        if videoConnection.isVideoMirroringSupported {
            videoConnection.isVideoMirrored = shouldMirror
        }
        
        // Depth connection
        if depthConnection.isVideoOrientationSupported {
            depthConnection.videoOrientation = orientation
        }
        if depthConnection.isVideoMirroringSupported {
            depthConnection.isVideoMirrored = shouldMirror
        }
        
        print("📐 CameraManager: Synchronized orientation for video and depth")
        print("   📹 Video - orientation: \(orientation.rawValue) (portrait), mirrored: \(shouldMirror)")
        print("   📊 Depth - orientation: \(orientation.rawValue) (portrait), mirrored: \(shouldMirror)")
    }
}

// MARK: - Zoom Presets
enum ZoomPreset: CGFloat, CaseIterable {
    case ultraWide = 0.5
    case wide = 1.0
    case telephoto = 2.0
    
    var title: String {
        switch self {
        case .ultraWide: return "0.5×"
        case .wide: return "1×"
        case .telephoto: return "2×"
        }
    }
}
