import CoreMedia
import Combine
import QuartzCore
import UIKit
internal import AVFoundation

enum FilterFamily: String {
    case depth = "DEPTH"
    case nonDepth = "NON-DEPTH"
}

final class FramePipeline: ObservableObject {

    static let shared = FramePipeline()

    private final class EffectPhaseController {
        var phase: Float = 0
        var smoothSpeed: Float = 0

        func update(dt: Float, intensity: Float) -> Float {
            let a = max(0, min(1, intensity))
            let target = (a * a) * 3.0
            let tau: Float = 0.18
            let k = 1 - exp(-dt / tau)
            smoothSpeed += (target - smoothSpeed) * k
            phase += dt * smoothSpeed
            return phase
        }
    }

    let gate = FrameGate()
    let mlEngine = MLInferenceEngine()

    weak var cameraManager: CameraManager?

    private let phaseController = EffectPhaseController()
    private var lastPhaseTime: CFTimeInterval = CACurrentMediaTime()
    @Published private(set) var demoPhase: Float = 0

    @Published private(set) var isDepthModeActive: Bool = false

    @Published var interfaceRotation: Float = 0.0
    private var orientationCancellable: AnyCancellable?

    @Published var isRecording: Bool = false
    private(set) var recordingFilterFamily: FilterFamily? = nil
    private var recordingDepthBuffer: CVPixelBuffer?
    private var recordingHasDepth: Bool = false

    @Published private(set) var targetIntensity: Float = 1.0
    @Published private(set) var smoothedIntensity: Float = 1.0

    private let smoothingAlpha: Float = 0.15
    private var displayLink: CADisplayLink?

    private var lastIntensityLogTime: CFTimeInterval = 0
    private let intensityLogInterval: CFTimeInterval = 0.1

    var currentFilterSupportsIntensity: Bool {
        activeFilter?.supportsIntensity ?? true
    }

    var activeFilter: FilterDefinition? = FilterLibrary.shared.filters.first {
        didSet {
            guard let filter = activeFilter else { return }

            let isFront = cameraManager?.isFrontCamera ?? false
            if isFront && filter.needsDepth {
                if let fallback = FilterLibrary.shared.firstNonDepthFilter() {
                    print("⛔️ Depth filter '\(filter.name)' selected on front camera -> switching to '\(fallback.name)'")
                    activeFilter = fallback
                    return
                }
            }

            if isRecording, let family = recordingFilterFamily {
                let filterFamily: FilterFamily = filter.needsDepth ? .depth : .nonDepth
                if filterFamily != family {
                    print("⛔️ Filter '\(filter.name)' blocked during recording (locked to \(family.rawValue) filters)")
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

            if isRecording {
                print("⛔️ Ignored depth reconfigure during recording - only shader change allowed")
                return
            }

            guard let camera = cameraManager else {
                print("⚠️ FramePipeline: No cameraManager reference for depth control")
                return
            }

            camera.applyDepthPolicy(needsDepth: filter.needsDepth, reason: "activeFilter changed to \(filter.name)")
            updateDepthModeActive()
        }
    }

    func updateDepthModeActive() {
        let newValue = activeFilter?.needsDepth == true || (cameraManager?.isDepthEnabled == true)
        if newValue != isDepthModeActive {
            DispatchQueue.main.async {
                self.isDepthModeActive = newValue
                print("🧭 UI depthModeActive = \(newValue)")
            }
        }
    }

    func setTargetIntensity(_ value: Float, reason: String = "") {
        let clamped = max(0.0, min(1.0, value))
        targetIntensity = clamped
        startSmoothingLoopIfNeeded()
    }

    private func startSmoothingLoopIfNeeded() {
        guard displayLink == nil else { return }
        displayLink = CADisplayLink(target: self, selector: #selector(updateSmoothedIntensity))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120)
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopSmoothingLoop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func updateSmoothedIntensity() {
        let diff = targetIntensity - smoothedIntensity

        if abs(diff) < 0.001 {
            smoothedIntensity = targetIntensity
            stopSmoothingLoop()
            return
        }

        smoothedIntensity += diff * smoothingAlpha

        let now = CACurrentMediaTime()
        if now - lastIntensityLogTime > intensityLogInterval {
            lastIntensityLogTime = now
            print("🎚️ target=\(String(format: "%.2f", targetIntensity)) smooth=\(String(format: "%.2f", smoothedIntensity))")
        }
    }

    func setEffectIntensity(_ value: Float) {
        setTargetIntensity(value, reason: "legacy call")
    }

    var effectIntensityForMetal: Float {
        guard currentFilterSupportsIntensity else { return 1.0 }
        return smoothedIntensity
    }

    func startRecording() {
        isRecording = true
        recordingHasDepth = activeFilter?.needsDepth == true && cameraManager?.isDepthEnabled == true
        recordingDepthBuffer = DepthManager.shared.latestDepthPixelBuffer
        recordingFilterFamily = (activeFilter?.needsDepth == true) ? .depth : .nonDepth
        print("🎬 FramePipeline: Recording started, hasDepth=\(recordingHasDepth)")
        print("🎥 Recording locked to \(recordingFilterFamily?.rawValue ?? "UNKNOWN") filters")
    }

    func stopRecording() {
        isRecording = false
        recordingDepthBuffer = nil
        recordingFilterFamily = nil
        print("🎬 FramePipeline: Recording stopped, filter lock released")
    }

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

            let now = CACurrentMediaTime()
            var dt = Float(now - self.lastPhaseTime)
            self.lastPhaseTime = now
            if dt.isNaN || dt.isInfinite { dt = 0 }
            dt = max(0, min(dt, 1.0 / 15.0))

            let intensity = self.effectIntensityForMetal
            let phase = self.phaseController.update(dt: dt, intensity: intensity)
            DispatchQueue.main.async {
                self.demoPhase = phase
            }

            let depthBuffer: CVPixelBuffer?

            if self.isRecording {
                if self.recordingHasDepth {
                    depthBuffer = self.recordingDepthBuffer ?? DepthManager.shared.latestDepthPixelBuffer
                } else {
                    depthBuffer = nil
                }
            } else {
                if self.activeFilter?.needsDepth == true && DepthManager.shared.isActive {
                    depthBuffer = DepthManager.shared.latestDepthPixelBuffer
                } else {
                    depthBuffer = nil
                }
            }

            let packet = FramePacket(
                pixelBuffer: pixelBuffer,
                time: time,
                depthPixelBuffer: depthBuffer
            )

            self.renderer?.render(packet: packet, activeFilter: self.activeFilter)
        }

        print("📱 Device: \(DeviceCapabilities.current.modelName)")
        print("📹 Max FPS: \(DeviceCapabilities.current.maxFPS)")
        print("🎬 FramePipeline: Initialized with filter '\(activeFilter?.name ?? "none")'")

        orientationCancellable = OrientationManager.shared.$rotationAngle
            .sink { [weak self] newRotation in
                self?.interfaceRotation = newRotation
                let degrees = Int(newRotation * 180 / .pi)
                print("🧭 FramePipeline: interfaceRotation updated = \(degrees)°")
            }
    }

    func setActiveFilter(by shaderName: String) {
        if let filter = FilterLibrary.shared.filter(for: shaderName) {
            activeFilter = filter
        }
    }
}
