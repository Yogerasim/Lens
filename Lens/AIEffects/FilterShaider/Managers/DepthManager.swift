internal import AVFoundation
import CoreVideo
import CoreMedia

final class DepthManager: NSObject {

    static let shared = DepthManager()

    /// Depth output для доступа из CameraManager
    private(set) var depthOutput: AVCaptureDepthDataOutput?

    private let depthQueue = DispatchQueue(label: "depth.data.queue", qos: .userInitiated)
    private(set) var latestDepthMap: CVPixelBuffer?
    private(set) var latestDepthTime: CMTime = .invalid
    
    private(set) var latestDepthPixelBuffer: CVPixelBuffer?

    /// Callback (если нужно)
    var onDepthMap: ((CVPixelBuffer, CMTime) -> Void)?

    private(set) var isActive: Bool = false

    // Throttle to 15 fps
    private let targetDepthFPS: Double = 15
    private lazy var minDepthInterval = CMTime(seconds: 1.0 / targetDepthFPS, preferredTimescale: 600)
    private var lastDeliveredTime: CMTime = .invalid
    
    // Throttle logging
    private var lastLogTime: CMTime = .invalid
    private let logInterval = CMTime(seconds: 2.0, preferredTimescale: 600)

    private override init() {
        super.init()
    }

    func setupDepthOutput(for session: AVCaptureSession) {

        let output = AVCaptureDepthDataOutput()
        output.setDelegate(self, callbackQueue: depthQueue)

        // ✅ FIX #2: discard late
        output.alwaysDiscardsLateDepthData = true

        // (опционально) Filtering часто добавляет latency. Для real-time я бы выключил:
        output.isFilteringEnabled = false

        guard session.canAddOutput(output) else {
            DebugLog.error("DepthManager: Cannot add depth output to session")
            isActive = false
            return
        }

        session.addOutput(output)
        depthOutput = output
        isActive = true

        if let connection = output.connection(with: .depthData) {
            connection.isEnabled = true
        } else {
            DebugLog.warning("DepthManager: No depth connection available")
        }

    }

    func removeDepthOutput(from session: AVCaptureSession) {
        guard let out = depthOutput else { return }
        session.removeOutput(out)
        depthOutput = nil
        isActive = false
        latestDepthMap = nil
        latestDepthTime = .invalid
        lastDeliveredTime = .invalid
    }

    static func isDepthSupported(for device: AVCaptureDevice) -> Bool {
        let supported = device.formats.contains { !$0.supportedDepthDataFormats.isEmpty }
        return supported
    }
}

extension DepthManager: AVCaptureDepthDataOutputDelegate {

    func depthDataOutput(
        _ output: AVCaptureDepthDataOutput,
        didOutput depthData: AVDepthData,
        timestamp: CMTime,
        connection: AVCaptureConnection
    ) {
        // Throttle to targetDepthFPS
        if lastDeliveredTime.isValid {
            let delta = CMTimeSubtract(timestamp, lastDeliveredTime)
            if delta < minDepthInterval { return }
        }
        lastDeliveredTime = timestamp

        // ✅ FIX: НЕ применяем EXIF orientation здесь!
        // Depth buffer должен быть в той же системе координат что и RGB buffer.
        // Трансформация (rotation/mirror) применяется в шейдере через uniforms.
        let depthMap = depthData.depthDataMap

        latestDepthMap = depthMap
        latestDepthPixelBuffer = depthMap
        latestDepthTime = timestamp
        
        // ✅ FIX: Обновляем hold-last depth buffer для записи
        FramePipeline.shared.updateRecordingDepthBuffer(depthMap)

        // Логи троттлим отдельно
        if lastLogTime.isValid == false || CMTimeSubtract(timestamp, lastLogTime) > logInterval {
            lastLogTime = timestamp
            let w = CVPixelBufferGetWidth(depthMap)
            let h = CVPixelBufferGetHeight(depthMap)
        }

        onDepthMap?(depthMap, timestamp)
    }

    func depthDataOutput(
        _ output: AVCaptureDepthDataOutput,
        didDrop depthData: AVDepthData,
        timestamp: CMTime,
        connection: AVCaptureConnection,
        reason: AVCaptureOutput.DataDroppedReason
    ) {
        // С discard late + throttle это должно резко уменьшиться
    }
}
