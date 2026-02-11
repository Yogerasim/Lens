//
//  DepthManager.swift
//  Lens
//
//  Created by Филипп Герасимов on 11/02/26.
//

import AVFoundation
import CoreVideo

final class DepthManager: NSObject {
    
    // MARK: - Singleton
    static let shared = DepthManager()
    
    // MARK: - Properties
    private var depthOutput: AVCaptureDepthDataOutput?
    private let depthQueue = DispatchQueue(label: "depth.data.queue", qos: .userInteractive)
    
    /// Callback для получения depth данных
    var onDepthData: ((AVDepthData) -> Void)?
    
    /// Последние depth данные
    private(set) var latestDepthData: AVDepthData?
    
    /// Флаг активности
    private(set) var isActive: Bool = false
    
    private override init() {
        super.init()
        print("🔵 DepthManager: Initialized")
    }
    
    // MARK: - Setup
    func setupDepthOutput(for session: AVCaptureSession) {
        print("🔵 DepthManager: Setting up depth output...")
        
        let depthOutput = AVCaptureDepthDataOutput()
        depthOutput.setDelegate(self, callbackQueue: depthQueue)
        depthOutput.isFilteringEnabled = true
        
        if session.canAddOutput(depthOutput) {
            session.addOutput(depthOutput)
            self.depthOutput = depthOutput
            self.isActive = true
            print("✅ DepthManager: Depth output added successfully")
            
            // Проверяем подключение
            if let connection = depthOutput.connection(with: .depthData) {
                connection.isEnabled = true
                print("✅ DepthManager: Depth connection enabled")
            } else {
                print("⚠️ DepthManager: No depth connection available")
            }
        } else {
            print("❌ DepthManager: Cannot add depth output to session")
            self.isActive = false
        }
    }
    
    // MARK: - Remove
    func removeDepthOutput(from session: AVCaptureSession) {
        guard let depthOutput = depthOutput else { return }
        
        session.removeOutput(depthOutput)
        self.depthOutput = nil
        self.isActive = false
        print("🔵 DepthManager: Depth output removed")
    }
    
    // MARK: - Check Device Support
    static func isDepthSupported(for device: AVCaptureDevice) -> Bool {
        let formats = device.formats.filter { format in
            format.supportedDepthDataFormats.count > 0
        }
        let supported = !formats.isEmpty
        print("🔵 DepthManager: Depth supported on \(device.localizedName): \(supported ? "YES" : "NO")")
        return supported
    }
}

// MARK: - AVCaptureDepthDataOutputDelegate
extension DepthManager: AVCaptureDepthDataOutputDelegate {
    
    func depthDataOutput(
        _ output: AVCaptureDepthDataOutput,
        didOutput depthData: AVDepthData,
        timestamp: CMTime,
        connection: AVCaptureConnection
    ) {
        // Конвертируем в нужный формат если необходимо
        let convertedDepth: AVDepthData
        if depthData.depthDataType != kCVPixelFormatType_DepthFloat32 {
            convertedDepth = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
            print("🔵 DepthManager: Converted depth to Float32")
        } else {
            convertedDepth = depthData
        }
        
        // Сохраняем последние данные
        self.latestDepthData = convertedDepth
        
        // Получаем информацию о depth map
        let depthMap = convertedDepth.depthDataMap
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        
        print("📊 DepthManager: Received depth data - \(width)x\(height), timestamp: \(timestamp.seconds)")
        
        // Вызываем callback
        onDepthData?(convertedDepth)
    }
    
    func depthDataOutput(
        _ output: AVCaptureDepthDataOutput,
        didDrop depthData: AVDepthData,
        timestamp: CMTime,
        connection: AVCaptureConnection,
        reason: AVCaptureOutput.DataDroppedReason
    ) {
        let reasonString: String
        switch reason {
        case .none:
            reasonString = "none"
        case .lateData:
            reasonString = "late data"
        case .outOfBuffers:
            reasonString = "out of buffers"
        case .discontinuity:
            reasonString = "discontinuity"
        @unknown default:
            reasonString = "unknown"
        }
        print("⚠️ DepthManager: Dropped depth frame - reason: \(reasonString)")
    }
}
