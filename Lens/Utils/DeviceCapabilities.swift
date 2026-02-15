import UIKit
internal import AVFoundation

// MARK: - Device Capabilities
struct DeviceCapabilities {
    let maxFPS: Int
    let modelName: String

    // Синглтон для текущего устройства
    static let current = DeviceCapabilities.detect()

    // Текущие размеры для записи (обновляются из MetalRenderer)
    static var currentCameraWidth: Int = 1080
    static var currentCameraHeight: Int = 1920

    /// Текущий размер для записи
    static var recordingSize: CGSize {
        CGSize(width: currentCameraWidth, height: currentCameraHeight)
    }

    private static func detect() -> DeviceCapabilities {
        let modelIdentifier = getModelIdentifier()
        let modelName = getModelName(from: modelIdentifier)

        if modelIdentifier.contains("iPhone15") ||
           modelIdentifier.contains("iPhone16") ||
           modelIdentifier.contains("iPhone17") ||
           modelIdentifier.contains("iPhone14") ||
           modelIdentifier.contains("iPhone13") {
            return DeviceCapabilities(maxFPS: 60, modelName: modelName)
        } else {
            return DeviceCapabilities(maxFPS: 30, modelName: modelName)
        }
    }

    private static func getModelIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }

    private static func getModelName(from identifier: String) -> String {
        switch identifier {
        // iPhone 16 серия
        case "iPhone17,1": return "iPhone 16 Pro"
        case "iPhone17,2": return "iPhone 16 Pro Max"
        case "iPhone17,3": return "iPhone 16"
        case "iPhone17,4": return "iPhone 16 Plus"
        // iPhone 15 серия
        case "iPhone16,1": return "iPhone 15 Pro"
        case "iPhone16,2": return "iPhone 15 Pro Max"
        case "iPhone15,4": return "iPhone 15"
        case "iPhone15,5": return "iPhone 15 Plus"
        // iPhone 14 серия
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"
        case "iPhone14,7": return "iPhone 14"
        case "iPhone14,8": return "iPhone 14 Plus"
        // iPhone 13 серия
        case "iPhone14,2": return "iPhone 13 Pro"
        case "iPhone14,3": return "iPhone 13 Pro Max"
        case "iPhone14,4": return "iPhone 13 mini"
        case "iPhone14,5": return "iPhone 13"
        // iPhone 12 серия
        case "iPhone13,1": return "iPhone 12 mini"
        case "iPhone13,2": return "iPhone 12"
        case "iPhone13,3": return "iPhone 12 Pro"
        case "iPhone13,4": return "iPhone 12 Pro Max"
        // Simulator
        case "x86_64", "arm64": return "Simulator"
        default: return identifier
        }
    }
}

// MARK: - Screen Size Helper
extension DeviceCapabilities {
    /// Размер экрана в пикселях (с учётом scale)
    static var screenPixelSize: CGSize {
        let screen = UIScreen.main
        let scale = screen.scale
        return CGSize(
            width: screen.bounds.width * scale,
            height: screen.bounds.height * scale
        )
    }
}
