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
        currentPosition == .front
    }
    
    /// Поворот для портретного режима
    /// Back camera: π/2 (90°), Front camera: -π/2 (-90°)
    var rotation: Float {
        if currentPosition == .front {
            return -Float.pi / 2.0
        } else {
            return Float.pi / 2.0
        }
    }
    
    /// Текущий зум фактор (логический: 0.5 / 1 / 2 / ...)
    @Published var currentZoomFactor: CGFloat = 1.0
    
    /// Статус depth (включён/выключен)
    @Published var isDepthEnabled: Bool = false
    
    /// Минимальный device zoom (для текущего active device)
    private var minZoomFactor: CGFloat = 1.0
    
    /// Максимальный device zoom (для текущего active device)
    private var maxZoomFactor: CGFloat = 10.0
    
    // MARK: - Private
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let outputQueue = DispatchQueue(label: "camera.output.queue")
    private let audioOutputQueue = DispatchQueue(label: "camera.audio.queue")
    
    nonisolated(unsafe) private let videoOutput = AVCaptureVideoDataOutput()
    nonisolated(unsafe) private let audioOutput = AVCaptureAudioDataOutput()
    
    private(set) var currentInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    
    /// Текущий тип back-камеры
    private var currentBackDeviceType: AVCaptureDevice.DeviceType = .builtInWideAngleCamera
    
    // MARK: - Zoom State
    private enum LensKind: String {
        case ultra
        case wide
        case tele
        case front
        case depth
    }
    
    private struct ZoomHysteresis {
        let wideToUltra: CGFloat = 0.90
        let ultraToWide: CGFloat = 0.98
        let wideToTele: CGFloat = 1.70
        let teleToWide: CGFloat = 1.55
    }
    
    private let zoomHysteresis = ZoomHysteresis()
    private var isZoomGestureActive = false
    private var lastRequestedLogicalZoom: CGFloat = 1.0
    private var lastAppliedLogicalZoom: CGFloat = 1.0
    private var lensSwitchWorkItem: DispatchWorkItem?
    private var lastLensSwitchTime: CFAbsoluteTime = 0
    private let minimumLensSwitchInterval: CFAbsoluteTime = 0.25
    
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
            
            
            self.configureOutputs()
            
            let desiredTypes: [AVCaptureDevice.DeviceType] = [
                .builtInWideAngleCamera,
                .builtInUltraWideCamera,
                .builtInTelephotoCamera
            ]
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: desiredTypes,
                mediaType: .video,
                position: self.currentPosition
            )
            
            if let videoDevice = discovery.devices.first(where: { $0.deviceType == .builtInWideAngleCamera }) ?? discovery.devices.first {
                self.configureCamera(device: videoDevice, enableDepth: false)
            } else {
                DebugLog.error("No video device found")
            }
            
            self.session.commitConfiguration()
        }
    }
    
    /// Настраиваем video и audio outputs
    private func configureOutputs() {
        configureAudioInput()
        
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: outputQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        
        audioOutput.setSampleBufferDelegate(self, queue: audioOutputQueue)
        if session.canAddOutput(audioOutput) {
            session.addOutput(audioOutput)
        }
    }
    
    /// Настраиваем аудио input
    private func configureAudioInput() {
        sessionQueue.async {
            if self.audioInput != nil { return }
            
            if AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
                if let mic = AVCaptureDevice.default(for: .audio) {
                    do {
                        let inAudio = try AVCaptureDeviceInput(device: mic)
                        if self.session.canAddInput(inAudio) {
                            self.session.addInput(inAudio)
                            self.audioInput = inAudio
                        }
                    } catch {
                        DebugLog.warning("Failed to create audio input: \(error)")
                    }
                } else {
                    DebugLog.warning("No audio device available")
                }
            } else {
                DebugLog.warning("Audio permission not granted")
            }
        }
    }
    
    // MARK: - Audio Setup
    func ensureAudioInput() {
        configureAudioInput()
    }
    
    // MARK: - Start/Stop
    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            requestAudioPermissionAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.requestAudioPermissionAndStart()
                } else {
                    DebugLog.error("Camera access denied")
                }
            }
        default:
            DebugLog.error("Camera access denied or restricted")
        }
    }
    
    private func requestAudioPermissionAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            startSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                self.startSession()
            }
        default:
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
                return
            }
            
            guard self.currentPosition == .back else {
                DebugLog.warning("CameraManager: Depth only available on back camera")
                return
            }
            
        }
    }
    
    func disableDepth() {
        sessionQueue.async {
            guard DepthManager.shared.isActive else {
                return
            }
            
            self.session.beginConfiguration()
            DepthManager.shared.removeDepthOutput(from: self.session)
            self.session.commitConfiguration()
            
        }
    }
    
    // MARK: - Switch Camera
    func switchCamera() {
        if FramePipeline.shared.isRecording {
            DebugLog.warning("CameraManager: Camera switch blocked during recording")
            return
        }
        
        if isDepthEnabled && currentPosition == .back {
            DebugLog.warning("CameraManager: Front camera blocked in depth mode")
            return
        }
        
        let newPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back
        
        
        sessionQueue.async {
            if self.isDepthEnabled && newPosition == .front {
                DebugLog.warning("CameraManager: Front camera blocked in depth mode (sessionQueue)")
                return
            }
            
            self.switchToDevice(type: .builtInWideAngleCamera, position: newPosition)
            
            if newPosition == .front {
                DispatchQueue.main.async {
                    if let currentFilter = FramePipeline.shared.activeFilter, currentFilter.needsDepth {
                        DebugLog.warning("CameraManager: Switching to front camera with depth filter active")
                        FramePipeline.shared.activeFilter = currentFilter
                    }
                }
            }
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
            DebugLog.error("CameraManager: No device for type: \(type) position: \(position)")
            return
        }
        
        DispatchQueue.main.async {
            self.currentPosition = position
        }
        
        if position == .back {
            currentBackDeviceType = device.deviceType
        }
        
        let newRotation = (position == .front) ? -Float.pi / 2.0 : Float.pi / 2.0
        
        let needsDepth = FramePipeline.shared.activeFilter?.needsDepth ?? false
        let enableDepth = position == .back && type == .builtInWideAngleCamera && needsDepth
        
        if enableDepth {
        } else {
        }
        
        session.beginConfiguration()
        DepthManager.shared.removeDepthOutput(from: session)
        configureCamera(device: device, enableDepth: enableDepth)
        session.commitConfiguration()
        
        updateZoomLimits(for: device)
        
        let resetLogical = position == .front ? 1.0 : lensBaseZoom(for: device.deviceType)
        DispatchQueue.main.async {
            self.currentZoomFactor = resetLogical
        }
    }
    
    private func updateZoomLimits(for device: AVCaptureDevice) {
        if #available(iOS 17.0, *) {
            minZoomFactor = max(1.0, device.minAvailableVideoZoomFactor)
        } else {
            minZoomFactor = 1.0
        }
        maxZoomFactor = min(10.0, device.activeFormat.videoMaxZoomFactor)
    }
    
    /// Универсальный метод конфигурации камеры (для обычного режима и depth)
    private func configureCamera(device: AVCaptureDevice, enableDepth: Bool) {
        
        if let existing = currentInput {
            session.removeInput(existing)
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                DebugLog.error("CameraManager: Cannot add device input")
                return
            }
            session.addInput(input)
            currentInput = input
            
            if currentPosition == .back {
                currentBackDeviceType = device.deviceType
            }
        } catch {
            DebugLog.error("CameraManager: Failed to create device input: \(error)")
            return
        }
        
        let selectedFormat: AVCaptureDevice.Format?
        
        if enableDepth {
            selectedFormat = findBestDepthFormat(for: device)
            if selectedFormat == nil {
                DebugLog.error("CameraManager: No depth-compatible format found")
                return
            }
        } else {
            selectedFormat = findBestFormat(for: device)
        }
        
        if let format = selectedFormat {
            configureFormat(device: device, format: format)
        }
        
        configureVideoConnection()
        
        if enableDepth {
            DepthManager.shared.setupDepthOutput(for: session)
            synchronizeDepthOrientation()
        } else {
            DepthManager.shared.removeDepthOutput(from: session)
        }
        
        updateZoomLimits(for: device)
        applyDeviceZoomForCurrentLogicalIfNeeded(on: device)
        
    }
    
    // MARK: - Format Selection
    private func findBestDepthFormat(for device: AVCaptureDevice) -> AVCaptureDevice.Format? {
        let depthFormats = device.formats.filter { !$0.supportedDepthDataFormats.isEmpty }
        guard !depthFormats.isEmpty else { return nil }
        
        let preferredWidths: [Int32] = [1920, 1280]
        
        for preferredWidth in preferredWidths {
            let candidates = depthFormats.filter {
                CMVideoFormatDescriptionGetDimensions($0.formatDescription).width == preferredWidth
            }
            if let best = candidates.max(by: { effectiveMaxFPS(for: $0) < effectiveMaxFPS(for: $1) }) {
                let dim = CMVideoFormatDescriptionGetDimensions(best.formatDescription)
                return best
            }
        }
        
        let fallback = depthFormats.max { lhs, rhs in
            let lhsFPS = effectiveMaxFPS(for: lhs)
            let rhsFPS = effectiveMaxFPS(for: rhs)
            if lhsFPS != rhsFPS { return lhsFPS < rhsFPS }
            
            let lhsDim = CMVideoFormatDescriptionGetDimensions(lhs.formatDescription)
            let rhsDim = CMVideoFormatDescriptionGetDimensions(rhs.formatDescription)
            return lhsDim.width * lhsDim.height < rhsDim.width * rhsDim.height
        }
        
        if let fallback {
            let dim = CMVideoFormatDescriptionGetDimensions(fallback.formatDescription)
        }
        
        return fallback
    }
    
    /// Находит лучший формат для устройства (без depth)
    private func findBestFormat(for device: AVCaptureDevice) -> AVCaptureDevice.Format? {
        let preferredFPS = Double(DeviceCapabilities.current.maxFPS)
        let preferredWidths: [Int32] = [1920, 1280]
        
        let formats = device.formats
        
        for preferredWidth in preferredWidths {
            let candidates = formats.filter {
                CMVideoFormatDescriptionGetDimensions($0.formatDescription).width == preferredWidth &&
                effectiveMaxFPS(for: $0) >= min(30.0, preferredFPS)
            }
            
            if let best = candidates.max(by: { scoreForVideoFormat($0, preferredFPS: preferredFPS) < scoreForVideoFormat($1, preferredFPS: preferredFPS) }) {
                let dim = CMVideoFormatDescriptionGetDimensions(best.formatDescription)
                return best
            }
        }
        
        let fallback = formats.max { scoreForVideoFormat($0, preferredFPS: preferredFPS) < scoreForVideoFormat($1, preferredFPS: preferredFPS) }
        if let fallback {
            let dim = CMVideoFormatDescriptionGetDimensions(fallback.formatDescription)
        }
        return fallback ?? device.activeFormat
    }
    
    private func scoreForVideoFormat(_ format: AVCaptureDevice.Format, preferredFPS: Double) -> Double {
        let maxFPS = effectiveMaxFPS(for: format)
        let dim = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
        let pixels = Double(dim.width * dim.height)
        
        let fpsScore: Double
        if maxFPS >= preferredFPS {
            fpsScore = 10_000
        } else if maxFPS >= 30 {
            fpsScore = 5_000
        } else {
            fpsScore = maxFPS * 100
        }
        
        let preferredResolutionBonus: Double
        switch dim.width {
        case 1920: preferredResolutionBonus = 2_000
        case 1280: preferredResolutionBonus = 1_000
        default: preferredResolutionBonus = 0
        }
        
        return fpsScore + preferredResolutionBonus + pixels / 1_000_000
    }
    
    private func effectiveMaxFPS(for format: AVCaptureDevice.Format) -> Double {
        let formatMax = format.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 30
        return min(formatMax, Double(DeviceCapabilities.current.maxFPS))
    }
    
    private func chooseFrameRate(for format: AVCaptureDevice.Format) -> Double {
        let formatMax = format.videoSupportedFrameRateRanges.map(\.maxFrameRate).max() ?? 30
        let desired = min(formatMax, Double(DeviceCapabilities.current.maxFPS))
        
        if desired >= 59.0 { return 60.0 }
        if desired >= 29.0 { return 30.0 }
        return max(1.0, floor(desired))
    }
    
    /// Конфигурирует формат и FPS для устройства
    private func configureFormat(device: AVCaptureDevice, format: AVCaptureDevice.Format) {
        let targetFPS = chooseFrameRate(for: format)
        
        do {
            try device.lockForConfiguration()
            
            if device.activeFormat != format {
                device.activeFormat = format
            }
            
            let frameDuration = CMTime(value: 1, timescale: CMTimeScale(targetFPS))
            device.activeVideoMinFrameDuration = frameDuration
            device.activeVideoMaxFrameDuration = frameDuration
            
            device.unlockForConfiguration()
            
            let dim = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            let depthSupported = !format.supportedDepthDataFormats.isEmpty
        } catch {
            DebugLog.error("CameraManager: Failed to configure format: \(error)")
        }
    }
    
    /// Конфигурирует video connection
    private func configureVideoConnection() {
        guard let connection = videoOutput.connection(with: .video) else {
            DebugLog.warning("CameraManager: No video connection found")
            return
        }
        
        let shouldMirror = currentPosition == .front
        
        if #available(iOS 17.0, *) {
            connection.videoRotationAngle = 90
        } else if connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        
        if connection.isVideoMirroringSupported {
            connection.isVideoMirrored = shouldMirror
        }
        
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate & AVCaptureAudioDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        if output == videoOutput {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            let callback = onFrame
            callback?(pixelBuffer, time)
        } else if output == audioOutput {
            let callback = onAudioSample
            callback?(sampleBuffer)
        }
    }
}

// MARK: - Zoom Control (iPhone Camera Style)
extension CameraManager {
    
    // MARK: - Public Properties for UI
    var hasUltraWideForUI: Bool { hasUltraWide && !isDepthEnabled && currentPosition == .back }
    var hasTelephotoForUI: Bool { hasTelephoto && !isDepthEnabled && currentPosition == .back }
    var maxDigitalZoomForUI: CGFloat { 9.0 }
    
    // MARK: - Private Helpers
    private var currentLensType: LensKind {
        if currentPosition == .front { return .front }
        if isDepthEnabled { return .depth }
        
        switch currentBackDeviceType {
        case .builtInUltraWideCamera: return .ultra
        case .builtInTelephotoCamera: return .tele
        default: return .wide
        }
    }
    
    private var lensBaseZoom: CGFloat {
        lensBaseZoom(for: currentBackDeviceType)
    }
    
    private func lensBaseZoom(for deviceType: AVCaptureDevice.DeviceType) -> CGFloat {
        switch deviceType {
        case .builtInUltraWideCamera: return 0.5
        case .builtInTelephotoCamera: return 2.0
        default: return 1.0
        }
    }
    
    private var minimumLogicalZoom: CGFloat {
        if currentPosition == .front { return 1.0 }
        if isDepthEnabled { return 1.0 }
        return hasUltraWide ? 0.5 : 1.0
    }
    
    private var maximumLogicalZoom: CGFloat {
        if currentPosition == .front || isDepthEnabled {
            return maxDigitalZoomForUI
        }
        
        let base = max(lensBaseZoom, hasTelephoto ? 2.0 : 1.0)
        return max(maxDigitalZoomForUI, base * maxZoomFactor)
    }
    
    private func clamp(_ value: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        min(max(value, lo), hi)
    }
    
    private func hasDevice(_ type: AVCaptureDevice.DeviceType) -> Bool {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [type],
            mediaType: .video,
            position: .back
        )
        return !discovery.devices.isEmpty
    }
    
    private var hasUltraWide: Bool { hasDevice(.builtInUltraWideCamera) }
    private var hasTelephoto: Bool { hasDevice(.builtInTelephotoCamera) }
    
    private func backDevice(for lens: LensKind) -> AVCaptureDevice? {
        let type: AVCaptureDevice.DeviceType
        
        switch lens {
        case .ultra:
            type = .builtInUltraWideCamera
        case .tele:
            type = .builtInTelephotoCamera
        case .wide, .depth, .front:
            type = .builtInWideAngleCamera
        }
        
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [type, .builtInWideAngleCamera, .builtInUltraWideCamera, .builtInTelephotoCamera],
            mediaType: .video,
            position: .back
        )
        return discovery.devices.first(where: { $0.deviceType == type }) ?? discovery.devices.first
    }
    
    /// Безопасно ставит device.videoZoomFactor (вызывать на sessionQueue)
    private func setDeviceZoomSafe(_ deviceZoom: CGFloat, on device: AVCaptureDevice? = nil) {
        guard let targetDevice = device ?? currentInput?.device else { return }
        let hwMax = targetDevice.activeFormat.videoMaxZoomFactor
        let clamped = max(1.0, min(deviceZoom, hwMax))
        
        do {
            try targetDevice.lockForConfiguration()
            targetDevice.videoZoomFactor = clamped
            targetDevice.unlockForConfiguration()
        } catch {
            DebugLog.error("Zoom error: \(error)")
        }
    }
    
    private func updateLogicalZoom(_ logical: CGFloat) {
        DispatchQueue.main.async {
            self.currentZoomFactor = logical
        }
    }
    
    private func applyDeviceZoomForCurrentLogicalIfNeeded(on device: AVCaptureDevice) {
        let base: CGFloat
        if currentPosition == .front || isDepthEnabled {
            base = 1.0
        } else {
            base = lensBaseZoom(for: device.deviceType)
        }
        
        let logical = clamp(lastAppliedLogicalZoom, minimumLogicalZoom, maximumLogicalZoom)
        let desiredDeviceZoom = clamp(logical / base, 1.0, device.activeFormat.videoMaxZoomFactor)
        setDeviceZoomSafe(desiredDeviceZoom, on: device)
    }
    
    private func desiredLensForEndedGesture(targetLogicalZoom logical: CGFloat) -> LensKind {
        let current = currentLensType
        
        guard currentPosition == .back, !isDepthEnabled else { return current }
        guard !FramePipeline.shared.isRecording else { return current }
        
        switch current {
        case .ultra:
            if logical > zoomHysteresis.ultraToWide {
                return .wide
            }
            return .ultra
            
        case .wide:
            if hasUltraWide && logical < zoomHysteresis.wideToUltra {
                return .ultra
            }
            if hasTelephoto && logical > zoomHysteresis.wideToTele {
                return .tele
            }
            return .wide
            
        case .tele:
            if logical < zoomHysteresis.teleToWide {
                return .wide
            }
            return .tele
            
        case .front, .depth:
            return current
        }
    }
    
    private func switchBackLens(to newLens: LensKind, targetLogicalZoom logical: CGFloat, reason: String) {
        guard currentPosition == .back else { return }
        guard !isDepthEnabled else { return }
        guard !FramePipeline.shared.isRecording else {
            DebugLog.warning("Lens switch blocked during recording")
            return
        }
        
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastLensSwitchTime >= minimumLensSwitchInterval else {
            applyDigitalZoomOnly(logical: logical, publishLogical: true)
            return
        }
        
        guard newLens != currentLensType else {
            applyDigitalZoomOnly(logical: logical, publishLogical: true)
            return
        }
        
        guard let targetDevice = backDevice(for: newLens) else {
            DebugLog.error("No target back device for lens \(newLens.rawValue)")
            applyDigitalZoomOnly(logical: logical, publishLogical: true)
            return
        }
        
        lastLensSwitchTime = now
        let targetBase = lensBaseZoom(for: targetDevice.deviceType)
        
        
        session.beginConfiguration()
        DepthManager.shared.removeDepthOutput(from: session)
        configureCamera(device: targetDevice, enableDepth: false)
        session.commitConfiguration()
        
        let deviceZoom = clamp(logical / targetBase, 1.0, targetDevice.activeFormat.videoMaxZoomFactor)
        setDeviceZoomSafe(deviceZoom, on: targetDevice)
        
        let appliedLogical = targetBase * deviceZoom
        lastAppliedLogicalZoom = appliedLogical
        lastRequestedLogicalZoom = appliedLogical
        
        updateLogicalZoom(appliedLogical)
    }
    
    private func applyDigitalZoomOnly(logical: CGFloat, publishLogical: Bool) {
        guard let device = currentInput?.device else { return }
        
        let requestedLogical = clamp(logical, minimumLogicalZoom, max(maxDigitalZoomForUI, maximumLogicalZoom))
        let base: CGFloat
        
        if currentPosition == .front || isDepthEnabled {
            base = 1.0
        } else {
            base = lensBaseZoom
        }
        
        let deviceZoom = clamp(requestedLogical / base, 1.0, device.activeFormat.videoMaxZoomFactor)
        setDeviceZoomSafe(deviceZoom, on: device)
        
        let publishedLogical = publishLogical ? requestedLogical : (base * deviceZoom)
        lastAppliedLogicalZoom = publishedLogical
        lastRequestedLogicalZoom = requestedLogical
        
        updateLogicalZoom(publishedLogical)
    }
    
    // MARK: - Public Zoom API
    func zoomGestureBegan() {
        sessionQueue.async {
            self.isZoomGestureActive = true
            self.lensSwitchWorkItem?.cancel()
            self.lensSwitchWorkItem = nil
            self.lastRequestedLogicalZoom = self.currentZoomFactor
        }
    }
    
    func zoomGestureChanged(logicalZoom: CGFloat) {
        guard logicalZoom.isFinite, logicalZoom > 0 else { return }
        
        sessionQueue.async {
            let clampedLogical = self.clamp(logicalZoom, self.minimumLogicalZoom, self.maxDigitalZoomForUI)
            
            // Depth / front / recording: всегда только digital
            if self.isDepthEnabled || self.currentPosition == .front || FramePipeline.shared.isRecording {
                self.applyDigitalZoomOnly(logical: clampedLogical, publishLogical: true)
                return
            }
            
            // During gesture: only digital in current lens, no physical lens switch.
            self.applyDigitalZoomOnly(logical: clampedLogical, publishLogical: true)
        }
    }
    
    func zoomGestureEnded(targetLogicalZoom: CGFloat) {
        guard targetLogicalZoom.isFinite, targetLogicalZoom > 0 else { return }
        
        sessionQueue.async {
            let clampedLogical = self.clamp(targetLogicalZoom, self.minimumLogicalZoom, self.maxDigitalZoomForUI)
            self.isZoomGestureActive = false
            self.lastRequestedLogicalZoom = clampedLogical
            
            if self.isDepthEnabled || self.currentPosition == .front || FramePipeline.shared.isRecording {
                self.applyDigitalZoomOnly(logical: clampedLogical, publishLogical: true)
                return
            }
            
            let desiredLens = self.desiredLensForEndedGesture(targetLogicalZoom: clampedLogical)
            let currentLens = self.currentLensType
            
            if desiredLens != currentLens {
                self.switchBackLens(to: desiredLens, targetLogicalZoom: clampedLogical, reason: "gestureEnded")
            } else {
                self.applyDigitalZoomOnly(logical: clampedLogical, publishLogical: true)
            }
        }
    }
    
    func jumpToPreset(logical: CGFloat) {
        guard logical.isFinite, logical > 0 else { return }
        
        sessionQueue.async {
            let targetLogical = self.clamp(logical, self.minimumLogicalZoom, self.maxDigitalZoomForUI)
            
            if self.isDepthEnabled {
                let depthLogical = max(1.0, targetLogical)
                self.applyDigitalZoomOnly(logical: depthLogical, publishLogical: true)
                return
            }
            
            if self.currentPosition == .front {
                let frontLogical = max(1.0, targetLogical)
                self.applyDigitalZoomOnly(logical: frontLogical, publishLogical: true)
                return
            }
            
            let desiredLens: LensKind
            if targetLogical <= 0.75, self.hasUltraWide {
                desiredLens = .ultra
            } else if targetLogical >= 2.0, self.hasTelephoto {
                desiredLens = .tele
            } else {
                desiredLens = .wide
            }
            
            if desiredLens != self.currentLensType {
                self.switchBackLens(to: desiredLens, targetLogicalZoom: targetLogical, reason: "presetTap")
            } else {
                self.applyDigitalZoomOnly(logical: targetLogical, publishLogical: true)
            }
        }
    }
    
    // MARK: - Compat API
    func smoothZoom(to logical: CGFloat) {
        zoomGestureChanged(logicalZoom: logical)
    }
    
    func setZoomDuringGesture(_ requestedLogical: CGFloat) {
        zoomGestureChanged(logicalZoom: requestedLogical)
    }
    
    func finalizeZoomAfterGesture(_ targetLogical: CGFloat) {
        zoomGestureEnded(targetLogicalZoom: targetLogical)
    }
    
    func setZoom(_ factor: CGFloat) {
        jumpToPreset(logical: factor)
    }
    
    /// Preset кнопки
    func zoom(to preset: ZoomPreset) {
        if isDepthEnabled && preset != .wide {
            DebugLog.warning("Zoom preset blocked in depth mode")
            return
        }
        jumpToPreset(logical: preset.rawValue)
    }
    
    // MARK: - Depth Management
    func applyDepthPolicy(needsDepth: Bool, reason: String) {
        
        if FramePipeline.shared.isRecording {
            DebugLog.warning("CameraManager: Depth policy change blocked during recording")
            return
        }
        
        let canUseDepth = currentPosition == .back
        
        if needsDepth && canUseDepth {
            setDepthEnabled(true, reason: reason)
        } else if needsDepth && !canUseDepth {
            DebugLog.error("CameraManager: Filter needs depth but we're on front camera - depth disabled")
            setDepthEnabled(false, reason: "Front camera doesn't support depth")
        } else {
            setDepthEnabled(false, reason: reason)
        }
    }
    
    private func setDepthEnabled(_ enabled: Bool, reason: String) {
        
        if enabled && currentPosition == .front {
            DebugLog.warning("CameraManager: Depth requested on front camera, ignoring")
            return
        }
        
        guard enabled != isDepthEnabled else {
            return
        }
        
        sessionQueue.async { [weak self] in
            guard let self else { return }
            
            self.session.beginConfiguration()
            defer { self.session.commitConfiguration() }
            
            if enabled {
                
                let lidarDiscovery = AVCaptureDevice.DiscoverySession(
                    deviceTypes: [.builtInLiDARDepthCamera],
                    mediaType: .video,
                    position: .back
                )
                
                if let lidarDevice = lidarDiscovery.devices.first {
                    self.lastAppliedLogicalZoom = 1.0
                    self.lastRequestedLogicalZoom = 1.0
                    self.configureCamera(device: lidarDevice, enableDepth: true)
                    
                    DispatchQueue.main.async {
                        self.isDepthEnabled = true
                        self.currentZoomFactor = 1.0
                    }
                } else {
                    
                    let wideDiscovery = AVCaptureDevice.DiscoverySession(
                        deviceTypes: [.builtInWideAngleCamera],
                        mediaType: .video,
                        position: .back
                    )
                    
                    if let wideDevice = wideDiscovery.devices.first {
                        let hasDepthFormats = wideDevice.formats.contains { !$0.supportedDepthDataFormats.isEmpty }
                        if hasDepthFormats {
                            self.lastAppliedLogicalZoom = 1.0
                            self.lastRequestedLogicalZoom = 1.0
                            self.configureCamera(device: wideDevice, enableDepth: true)
                            
                            DispatchQueue.main.async {
                                self.isDepthEnabled = true
                                self.currentZoomFactor = 1.0
                            }
                        } else {
                            DebugLog.error("CameraManager: No depth support available on this device")
                        }
                    }
                }
            } else {
                
                let wideDiscovery = AVCaptureDevice.DiscoverySession(
                    deviceTypes: [.builtInWideAngleCamera],
                    mediaType: .video,
                    position: .back
                )
                
                if let wideDevice = wideDiscovery.devices.first {
                    self.lastAppliedLogicalZoom = 1.0
                    self.lastRequestedLogicalZoom = 1.0
                    self.configureCamera(device: wideDevice, enableDepth: false)
                }
                
                DispatchQueue.main.async {
                    self.isDepthEnabled = false
                    self.currentZoomFactor = 1.0
                }
            }
        }
    }
    
    /// Синхронизирует orientation для video и depth outputs
    private func synchronizeDepthOrientation() {
        guard let videoConnection = videoOutput.connection(with: .video),
              let depthOutput = DepthManager.shared.depthOutput,
              let depthConnection = depthOutput.connection(with: .depthData) else {
            DebugLog.warning("CameraManager: Cannot synchronize - missing connections")
            return
        }
        
        let shouldMirror = currentPosition == .front
        
        if #available(iOS 17.0, *) {
            if videoConnection.isVideoRotationAngleSupported(90) {
                videoConnection.videoRotationAngle = 90
            }
        } else if videoConnection.isVideoOrientationSupported {
            videoConnection.videoOrientation = .portrait
        }
        
        if videoConnection.isVideoMirroringSupported {
            videoConnection.isVideoMirrored = shouldMirror
        }
        
        if #available(iOS 17.0, *) {
            if depthConnection.isVideoRotationAngleSupported(90) {
                depthConnection.videoRotationAngle = 90
            }
        } else if depthConnection.isVideoOrientationSupported {
            depthConnection.videoOrientation = .portrait
        }
        
        if depthConnection.isVideoMirroringSupported {
            depthConnection.isVideoMirrored = shouldMirror
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
