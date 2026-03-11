internal import AVFoundation
import CoreVideo
import Combine

final class CameraManager: NSObject, ObservableObject {
    @Published var currentPosition: AVCaptureDevice.Position = .back
    @Published var currentZoomFactor: CGFloat = 1.0
    @Published var isDepthEnabled: Bool = false

    /// When false, all zoom is digital-only (no physical lens switching).
    /// Applies only to rear non-LiDAR camera.
    var usePhysicalLenses: Bool {
        UserDefaults.standard.bool(forKey: "zoom_usePhysicalLenses")
    }

    var onFrame: ((CVPixelBuffer, CMTime) -> Void)? {
        get { sessionController.onFrame }
        set { sessionController.onFrame = newValue }
    }

    var onAudioSample: ((CMSampleBuffer) -> Void)? {
        get { sessionController.onAudioSample }
        set { sessionController.onAudioSample = newValue }
    }

    var session: AVCaptureSession {
        sessionController.session
    }

    var isFrontCamera: Bool {
        currentPosition == .front
    }

    var rotation: Float {
        currentPosition == .front ? -Float.pi / 2.0 : Float.pi / 2.0
    }

    var activeVideoDevice: AVCaptureDevice? {
        sessionController.currentInput?.device
    }

    private var minZoomFactor: CGFloat = 1.0
    private var maxZoomFactor: CGFloat = 10.0
    private var currentBackDeviceType: AVCaptureDevice.DeviceType = .builtInWideAngleCamera

    private var backCapabilities: CameraCapabilities {
        CameraCapabilities.make(position: .back)
    }

    private var frontCapabilities: CameraCapabilities {
        CameraCapabilities.make(position: .front)
    }

    private var currentCapabilities: CameraCapabilities {
        currentPosition == .front ? frontCapabilities : backCapabilities
    }

    private let sessionController = CameraSessionController()
    private let formatSelector = CameraFormatSelector()
    private let deviceConfigurator = CameraDeviceConfigurator()
    private let zoomController = CameraZoomController()
    private let depthController = DepthController()

    private var sessionQueue: DispatchQueue { sessionController.sessionQueue }

    /// Expose zoom controller for UI binding (ZoomGlassBar, pinch gestures)
    var zoomControllerForUI: CameraZoomController { zoomController }

    override init() {
        super.init()
        UserDefaults.standard.register(defaults: ["zoom_usePhysicalLenses": true])
        zoomController.manager = self
        zoomController.capabilities = backCapabilities
        configureSession()
    }

    private func configureSession() {
        sessionQueue.async {
            self.sessionController.beginConfiguration()
            self.session.sessionPreset = .inputPriority
            self.sessionController.configureOutputs()

            if let videoDevice = self.backCapabilities.wideDevice ?? self.backCapabilities.devices.first {
                self.applyCameraConfiguration(
                    device: videoDevice,
                    enableDepth: false
                )
            } else {
                DebugLog.error("No video device found")
            }

            self.sessionController.commitConfiguration()
        }
    }

    func ensureAudioInput() {
        sessionController.configureAudioInputIfNeeded()
    }

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
            sessionController.startSession { [weak self] device in
                self?.updateZoomLimits(for: device)
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                self.sessionController.startSession { [weak self] device in
                    self?.updateZoomLimits(for: device)
                }
            }
        default:
            sessionController.startSession { [weak self] device in
                self?.updateZoomLimits(for: device)
            }
        }
    }

    func stop() {
        sessionController.stopSession()
    }

    func enableDepth() {
        sessionQueue.async {
            guard !DepthManager.shared.isActive else { return }

            guard self.currentPosition == .back else {
                DebugLog.warning("CameraManager: Depth only available on back camera")
                return
            }
        }
    }

    func disableDepth() {
        sessionQueue.async {
            guard DepthManager.shared.isActive else { return }
            self.sessionController.beginConfiguration()
            DepthManager.shared.removeDepthOutput(from: self.session)
            self.sessionController.commitConfiguration()
        }
    }

    func switchCamera() {
        let newPosition: AVCaptureDevice.Position = currentPosition == .back ? .front : .back

        if isDepthEnabled && newPosition == .front {
            DebugLog.warning("CameraManager: Front camera blocked in depth mode")
            return
        }

        sessionQueue.async {
            if self.isDepthEnabled && newPosition == .front {
                DebugLog.warning("CameraManager: Front camera blocked in depth mode (sessionQueue)")
                return
            }

            self.switchToDevice(type: .builtInWideAngleCamera, position: newPosition)

            if newPosition == .front {
                DispatchQueue.main.async {
                    if let currentFilter = FramePipeline.shared.activeFilter, currentFilter.needsDepth {
                        FramePipeline.shared.activeFilter = currentFilter
                    }
                }
            }
        }
    }

    private func switchToDevice(type: AVCaptureDevice.DeviceType, position: AVCaptureDevice.Position) {
        let capabilities = CameraCapabilities.make(position: position)

        guard let device = capabilities.device(for: type) ?? capabilities.devices.first else {
            DebugLog.error("CameraManager: No device for type: \(type) position: \(position)")
            return
        }

        DispatchQueue.main.async {
            self.currentPosition = position
        }

        if position == .back {
            currentBackDeviceType = device.deviceType
            zoomController.capabilities = capabilities
        }

        let needsDepth = FramePipeline.shared.activeFilter?.needsDepth ?? false
        let enableDepth = position == .back && type == .builtInWideAngleCamera && needsDepth

        sessionController.beginConfiguration()
        applyCameraConfiguration(device: device, enableDepth: enableDepth)
        sessionController.commitConfiguration()

        updateZoomLimits(for: device)

        let resetLogical = position == .front ? 1.0 : zoomController.lensBaseZoom(for: device.deviceType)
        zoomController.reset(logicalZoom: resetLogical)

        DispatchQueue.main.async {
            self.currentZoomFactor = resetLogical
        }
    }

    private func applyCameraConfiguration(device: AVCaptureDevice, enableDepth: Bool) {
        do {
            let input = try deviceConfigurator.configureCamera(
                session: session,
                currentInput: sessionController.currentInput,
                device: device,
                enableDepth: enableDepth,
                currentPosition: currentPosition,
                videoOutput: sessionController.videoOutput,
                formatSelector: formatSelector
            )

            sessionController.replaceCurrentInput(with: input)

            if currentPosition == .back {
                currentBackDeviceType = device.deviceType
            }

            updateZoomLimits(for: device)
            zoomController.applyDeviceZoomForCurrentLogicalIfNeeded(
                context: zoomContext(currentDevice: device),
                device: device
            ) { [weak self] zoom, targetDevice in
                self?.setDeviceZoomSafe(zoom, on: targetDevice)
            }
        } catch let error as CameraDeviceConfigurator.ConfigurationError {
            DebugLog.error("CameraManager: \(error.localizedDescription)")
        } catch {
            DebugLog.error("CameraManager: Failed to configure device: \(error)")
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
}

extension CameraManager {
    var hasUltraWideForUI: Bool {
        currentPosition == .back && !isDepthEnabled && backCapabilities.hasUltraWide
    }

    var hasTelephotoForUI: Bool {
        currentPosition == .back && !isDepthEnabled && backCapabilities.hasTelephoto
    }

    var maxDigitalZoomForUI: CGFloat {
        currentCapabilities.maxLogicalZoom
    }

    private var currentLensType: CameraLensKind {
        zoomController.currentLensType(
            currentPosition: currentPosition,
            isDepthEnabled: isDepthEnabled,
            currentBackDeviceType: currentBackDeviceType
        )
    }

    private var minimumLogicalZoom: CGFloat {
        zoomController.minimumLogicalZoom(
            capabilities: currentCapabilities,
            isDepthEnabled: isDepthEnabled,
            isFront: currentPosition == .front
        )
    }

    private var maximumLogicalZoom: CGFloat {
        zoomController.maximumLogicalZoom(
            capabilities: currentCapabilities,
            isDepthEnabled: isDepthEnabled,
            isFront: currentPosition == .front
        )
    }

    private func clamp(_ value: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
        zoomController.clamp(value, min: lo, max: hi)
    }

    private func zoomContext(currentDevice: AVCaptureDevice? = nil) -> CameraZoomControllerContext {
        CameraZoomControllerContext(
            currentPosition: currentPosition,
            isDepthEnabled: isDepthEnabled,
            isRecording: FramePipeline.shared.isRecording,
            currentBackDeviceType: currentBackDeviceType,
            currentCapabilities: currentCapabilities,
            backCapabilities: backCapabilities,
            currentDeviceMaxZoomFactor: currentDevice?.activeFormat.videoMaxZoomFactor ?? sessionController.currentInput?.device.activeFormat.videoMaxZoomFactor ?? maxZoomFactor
        )
    }

    private func backDevice(for lens: CameraLensKind) -> AVCaptureDevice? {
        zoomController.backDevice(for: lens, capabilities: backCapabilities)
    }

    private func setDeviceZoomSafe(_ deviceZoom: CGFloat, on device: AVCaptureDevice? = nil) {
        guard let targetDevice = device ?? sessionController.currentInput?.device else { return }
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

    private func applyDigitalZoomOnly(logical: CGFloat, publishLogical: Bool) {
        guard let publishedLogical = zoomController.applyDigitalZoomOnly(
            requestedLogical: logical,
            context: zoomContext(),
            publishLogical: publishLogical,
            setDeviceZoom: { [weak self] zoom, device in
                self?.setDeviceZoomSafe(zoom, on: device)
            }
        ) else { return }

        updateLogicalZoom(publishedLogical)
    }

    private func desiredLensForLiveZoom(targetLogicalZoom logical: CGFloat) -> CameraLensKind {
        zoomController.desiredLensForLiveZoom(
            targetLogicalZoom: logical,
            context: zoomContext()
        )
    }

    private func desiredLensForEndedGesture(targetLogicalZoom logical: CGFloat) -> CameraLensKind {
        zoomController.desiredLensForEndedGesture(
            targetLogicalZoom: logical,
            context: zoomContext()
        )
    }

    private func switchBackLens(to newLens: CameraLensKind, targetLogicalZoom logical: CGFloat, reason: String) {
        guard currentPosition == .back else { return }
        guard !isDepthEnabled else { return }

        let now = CFAbsoluteTimeGetCurrent()
        guard zoomController.canSwitchLens(now: now) else {
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

        zoomController.markLensSwitch(now: now)
        let targetBase = zoomController.lensBaseZoom(for: targetDevice.deviceType)

        sessionController.beginConfiguration()
        applyCameraConfiguration(device: targetDevice, enableDepth: false)
        sessionController.commitConfiguration()

        let deviceZoom = clamp(logical / targetBase, 1.0, targetDevice.activeFormat.videoMaxZoomFactor)
        setDeviceZoomSafe(deviceZoom, on: targetDevice)

        let appliedLogical = targetBase * deviceZoom
        zoomController.updateAppliedLogicalZoom(appliedLogical)
        updateLogicalZoom(appliedLogical)
    }

    func zoomGestureBegan() {
        sessionQueue.async {
            self.zoomController.beginGesture(currentLogicalZoom: self.currentZoomFactor)
        }
    }

    func zoomGestureChanged(logicalZoom: CGFloat) {
        guard logicalZoom.isFinite, logicalZoom > 0 else { return }

        sessionQueue.async {
            let clampedLogical = self.clamp(logicalZoom, self.minimumLogicalZoom, self.maxDigitalZoomForUI)
            self.applyDigitalZoomOnly(logical: clampedLogical, publishLogical: true)

            // Physical lens switching: only for back camera, non-depth, with setting enabled
            if self.currentPosition == .back && !self.isDepthEnabled && self.usePhysicalLenses {
                let desiredLens = self.desiredLensForLiveZoom(targetLogicalZoom: clampedLogical)
                if desiredLens != self.currentLensType {
                    self.switchBackLens(to: desiredLens, targetLogicalZoom: clampedLogical, reason: "liveZoom")
                }
            }
        }
    }

    func zoomGestureEnded(targetLogicalZoom: CGFloat) {
        guard targetLogicalZoom.isFinite, targetLogicalZoom > 0 else { return }

        sessionQueue.async {
            let clampedLogical = self.clamp(targetLogicalZoom, self.minimumLogicalZoom, self.maxDigitalZoomForUI)
            self.zoomController.endGesture(targetLogicalZoom: clampedLogical)

            // Digital-only for depth, front, or when physical lenses disabled
            if self.isDepthEnabled || self.currentPosition == .front || !self.usePhysicalLenses {
                self.applyDigitalZoomOnly(logical: clampedLogical, publishLogical: true)
                return
            }

            let desiredLens = self.desiredLensForEndedGesture(targetLogicalZoom: clampedLogical)

            if desiredLens != self.currentLensType {
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

            // Physical lens switching for presets (always, even when digital-only mode)
            // Presets are explicit user intent so we switch lenses for them
            if self.usePhysicalLenses {
                let desiredLens = self.zoomController.preferredLensForPreset(
                    logicalZoom: targetLogical,
                    context: self.zoomContext()
                )

                if desiredLens != self.currentLensType {
                    self.switchBackLens(to: desiredLens, targetLogicalZoom: targetLogical, reason: "presetTap")
                } else {
                    self.applyDigitalZoomOnly(logical: targetLogical, publishLogical: true)
                }
            } else {
                self.applyDigitalZoomOnly(logical: targetLogical, publishLogical: true)
            }
        }
    }

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

    func zoom(to preset: ZoomPreset) {
        if isDepthEnabled && preset != .wide {
            DebugLog.warning("Zoom preset blocked in depth mode")
            return
        }
        jumpToPreset(logical: preset.rawValue)
    }
}

extension CameraManager {
    func applyDepthPolicy(needsDepth: Bool, reason: String) {
        depthController.applyDepthPolicy(
            needsDepth: needsDepth,
            isRecording: FramePipeline.shared.isRecording,
            currentPosition: currentPosition,
            reason: reason
        ) { [weak self] enabled, reason in
            self?.setDepthEnabled(enabled, reason: reason)
        }
    }

    private func setDepthEnabled(_ enabled: Bool, reason: String) {
        depthController.setDepthEnabled(
            enabled,
            currentPosition: currentPosition,
            isDepthEnabled: isDepthEnabled,
            backCapabilities: backCapabilities,
            sessionQueue: sessionQueue,
            beginConfiguration: { [weak self] in
                self?.sessionController.beginConfiguration()
            },
            commitConfiguration: { [weak self] in
                self?.sessionController.commitConfiguration()
            },
            applyCameraConfiguration: { [weak self] device, enableDepth in
                self?.applyCameraConfiguration(device: device, enableDepth: enableDepth)
            },
            resetZoom: { [weak self] logicalZoom in
                self?.zoomController.reset(logicalZoom: logicalZoom)
            },
            publishDepthState: { [weak self] depthEnabled, logicalZoom in
                DispatchQueue.main.async {
                    self?.isDepthEnabled = depthEnabled
                    self?.currentZoomFactor = logicalZoom
                }
            }
        )
    }
}

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
