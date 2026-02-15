internal import AVFoundation
import CoreVideo
import CoreMedia

final class DepthManager: NSObject {

    static let shared = DepthManager()

    private var depthOutput: AVCaptureDepthDataOutput?
    private let depthQueue = DispatchQueue(label: "depth.data.queue", qos: .userInitiated)
    
    

    /// Последняя depth map (CVPixelBuffer). Формат зависит от камеры (часто DepthFloat16 / Disparity).
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
        print("🔵 DepthManager: Initialized")
    }

    func setupDepthOutput(for session: AVCaptureSession) {
        print("🔵 DepthManager: Setting up depth output...")

        let output = AVCaptureDepthDataOutput()
        output.setDelegate(self, callbackQueue: depthQueue)

        // ✅ FIX #2: discard late
        output.alwaysDiscardsLateDepthData = true

        // (опционально) Filtering часто добавляет latency. Для real-time я бы выключил:
        output.isFilteringEnabled = false

        guard session.canAddOutput(output) else {
            print("❌ DepthManager: Cannot add depth output to session")
            isActive = false
            return
        }

        session.addOutput(output)
        depthOutput = output
        isActive = true

        if let connection = output.connection(with: .depthData) {
            connection.isEnabled = true
            print("✅ DepthManager: Depth connection enabled")
        } else {
            print("⚠️ DepthManager: No depth connection available")
        }

        print("✅ DepthManager: Depth output added successfully")
    }

    func removeDepthOutput(from session: AVCaptureSession) {
        guard let out = depthOutput else { return }
        session.removeOutput(out)
        depthOutput = nil
        isActive = false
        latestDepthMap = nil
        latestDepthTime = .invalid
        lastDeliveredTime = .invalid
        print("🔵 DepthManager: Depth output removed")
    }

    static func isDepthSupported(for device: AVCaptureDevice) -> Bool {
        let supported = device.formats.contains { !$0.supportedDepthDataFormats.isEmpty }
        print("🔵 DepthManager: Depth supported on \(device.localizedName): \(supported ? "YES" : "NO")")
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

        // Получаем depth map без конвертации
        let depthMap = depthData.depthDataMap

        latestDepthMap = depthMap
        latestDepthPixelBuffer = depthMap
        latestDepthTime = timestamp

        // Логи троттлим отдельно
        if lastLogTime.isValid == false || CMTimeSubtract(timestamp, lastLogTime) > logInterval {
            lastLogTime = timestamp
            let w = CVPixelBufferGetWidth(depthMap)
            let h = CVPixelBufferGetHeight(depthMap)
            print("📊 DepthManager: depth \(w)x\(h), ts: \(String(format: "%.2f", timestamp.seconds))")
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
        print("⚠️ DepthManager: Dropped depth frame - \(reason)")
    }
}
