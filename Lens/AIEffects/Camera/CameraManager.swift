import AVFoundation
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
    
    /// Поворот для портретного режима (90 градусов в радианах)
    var rotation: Float {
        return Float.pi / 2.0  // 90 градусов для портрета
    }
    
    /// Текущий зум фактор
    @Published var currentZoomFactor: CGFloat = 1.0
    
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
    private var currentInput: AVCaptureDeviceInput?
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
            
            // Пробуем сначала LiDAR камеру для depth, иначе обычную широкоугольную
            var videoDevice: AVCaptureDevice?
            
            // Попробуем LiDAR камеру (builtInLiDARDepthCamera)
            if let lidarDevice = AVCaptureDevice.default(.builtInLiDARDepthCamera, for: .video, position: self.currentPosition) {
                videoDevice = lidarDevice
                print("✅ CameraManager: Using LiDAR depth camera")
            } else {
                // Fallback на обычную широкоугольную камеру
                let desiredTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera]
                let discovery = AVCaptureDevice.DiscoverySession(
                    deviceTypes: desiredTypes,
                    mediaType: .video,
                    position: self.currentPosition
                )
                videoDevice = discovery.devices.first(where: { $0.deviceType == .builtInWideAngleCamera }) ?? discovery.devices.first
                print("🔵 CameraManager: Using standard camera (no LiDAR)")
            }
            
            // Remove old inputs if any
            if let existing = self.currentInput {
                self.session.removeInput(existing)
                self.currentInput = nil
            }
            
            if let device = videoDevice {
                do {
                    let input = try AVCaptureDeviceInput(device: device)
                    if self.session.canAddInput(input) {
                        self.session.addInput(input)
                        self.currentInput = input
                        if self.currentPosition == .back {
                            self.currentBackDeviceType = device.deviceType
                        }
                    }
                } catch {
                    print("❌ Failed to create video input: \(error)")
                }
            } else {
                print("❌ No video device found")
            }
            
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
            
            // Orientation / rotation for portrait
            if let connection = self.videoOutput.connection(with: .video) {
                if #available(iOS 17.0, *) {
                    connection.videoRotationAngle = 0 // не вращаем буфер, поворот в шейдере
                } else {
                    if connection.isVideoOrientationSupported {
                        connection.videoOrientation = .portrait // влияет на метаданные, не на буфер
                    }
                }
                // Mirror выключен — зеркалим в шейдере
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = false
                }
            }
            
            // Update zoom limits and configure depth
            if let device = self.currentInput?.device {
                self.updateZoomLimits(for: device)
                
                // Configure format with depth support
                self.configureDepthFormat(for: device)
                
                // Configure frame rate to max FPS
                self.configureFrameRate(for: device)
            }
            
            self.session.commitConfiguration()
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
    
    // MARK: - Switch Camera
    func switchCamera() {
        sessionQueue.async {
            let newPosition: AVCaptureDevice.Position = self.currentPosition == .back ? .front : .back
            self.switchToDevice(type: .builtInWideAngleCamera, position: newPosition)
        }
    }
    
    // MARK: - Internal helpers
    private func switchToDevice(type: AVCaptureDevice.DeviceType, position: AVCaptureDevice.Position) {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInUltraWideCamera, .builtInWideAngleCamera, .builtInTelephotoCamera],
            mediaType: .video,
            position: position
        )
        guard let device = discovery.devices.first(where: { $0.deviceType == type }) ?? discovery.devices.first else {
            print("❌ No device for type: \(type) position: \(position)")
            return
        }
        do {
            let newInput = try AVCaptureDeviceInput(device: device)
            session.beginConfiguration()
            
            // Удаляем depth output если меняем камеру
            DepthManager.shared.removeDepthOutput(from: session)
            
            if let currentInput = self.currentInput {
                session.removeInput(currentInput)
            }
            if session.canAddInput(newInput) { session.addInput(newInput) }
            self.currentInput = newInput
            self.currentPosition = position
            if position == .back { self.currentBackDeviceType = device.deviceType }
            
            // Orientation
            if let connection = self.videoOutput.connection(with: .video) {
                if #available(iOS 17.0, *) {
                    connection.videoRotationAngle = 0 // не вращаем буфер, поворот в шейдере
                } else {
                    connection.videoOrientation = .portrait
                }
                // Mirror всегда выключен — зеркалим в шейдере
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = false
                }
            }
            
            // Настраиваем FPS для новой камеры
            self.configureFrameRate(for: device)
            
            // LiDAR только на back camera с wide (x1)
            if position == .back && type == .builtInWideAngleCamera {
                self.configureDepthFormat(for: device)
            }
            
            session.commitConfiguration()
            
            self.updateZoomLimits(for: device)
            self.setZoom(1.0) // Сбросить на оптический базовый зум
            
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
    
    // MARK: - Depth Configuration
    private func configureDepthFormat(for device: AVCaptureDevice) {
        let targetFPS = Double(DeviceCapabilities.current.maxFPS)
        
        // Find formats that support depth
        let depthFormats = device.formats.filter { format in
            !format.supportedDepthDataFormats.isEmpty
        }
        
        guard !depthFormats.isEmpty else {
            print("⚠️ CameraManager: No formats with depth support found for \(device.localizedName)")
            return
        }
        
        print("🔵 CameraManager: Found \(depthFormats.count) formats with depth support")
        
        // Find the best format with depth and target FPS support
        for format in depthFormats {
            let ranges = format.videoSupportedFrameRateRanges
            let supportsTargetFPS = ranges.contains { $0.maxFrameRate >= targetFPS }
            
            guard supportsTargetFPS else { continue }
            guard let depthFormat = format.supportedDepthDataFormats.first else { continue }
            
            do {
                try device.lockForConfiguration()
                device.activeFormat = format
                device.activeDepthDataFormat = depthFormat
                
                // Устанавливаем target FPS
                let frameDuration = CMTime(value: 1, timescale: CMTimeScale(targetFPS))
                device.activeVideoMinFrameDuration = frameDuration
                device.activeVideoMaxFrameDuration = frameDuration
                
                device.unlockForConfiguration()
                
                let dim = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                let depthDim = CMVideoFormatDescriptionGetDimensions(depthFormat.formatDescription)
                print("✅ CameraManager: Configured depth format - video: \(dim.width)x\(dim.height), depth: \(depthDim.width)x\(depthDim.height) at \(Int(targetFPS)) FPS")
                
                // Setup DepthManager
                DepthManager.shared.setupDepthOutput(for: self.session)
                return
            } catch {
                print("❌ CameraManager: Failed to configure depth format: \(error)")
            }
        }
        
        print("⚠️ CameraManager: Could not find suitable depth format with \(Int(targetFPS)) FPS")
    }
    
    // MARK: - Frame Rate Configuration
    private func configureFrameRate(for device: AVCaptureDevice) {
        let targetFPS = Double(DeviceCapabilities.current.maxFPS)
        
        // Найдём формат, поддерживающий target FPS
        var bestFormat: AVCaptureDevice.Format?
        var bestFrameRateRange: AVFrameRateRange?
        
        for format in device.formats {
            for range in format.videoSupportedFrameRateRanges {
                if range.maxFrameRate >= targetFPS {
                    // Предпочитаем формат с более высоким разрешением
                    if bestFormat == nil {
                        bestFormat = format
                        bestFrameRateRange = range
                    } else {
                        let currentDim = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
                        let bestDim = CMVideoFormatDescriptionGetDimensions(bestFormat!.formatDescription)
                        if currentDim.width * currentDim.height > bestDim.width * bestDim.height {
                            bestFormat = format
                            bestFrameRateRange = range
                        }
                    }
                }
            }
        }
        
        guard let format = bestFormat, let range = bestFrameRateRange else {
            print("⚠️ CameraManager: No format supports \(targetFPS) FPS")
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            // Устанавливаем формат если он отличается от текущего
            if device.activeFormat != format {
                device.activeFormat = format
            }
            
            // Устанавливаем frame rate
            let frameDuration = CMTime(value: 1, timescale: CMTimeScale(targetFPS))
            device.activeVideoMinFrameDuration = frameDuration
            device.activeVideoMaxFrameDuration = frameDuration
            
            device.unlockForConfiguration()
            
            let dim = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            print("✅ CameraManager: Configured \(Int(targetFPS)) FPS at \(dim.width)x\(dim.height)")
        } catch {
            print("❌ CameraManager: Failed to configure frame rate: \(error)")
        }
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
