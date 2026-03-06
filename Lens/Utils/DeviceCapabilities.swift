internal import AVFoundation
import UIKit

struct DeviceCapabilities {
  let maxFPS: Int
  let modelName: String

  static let current = DeviceCapabilities.detect()

  static var currentCameraWidth: Int = 1080
  static var currentCameraHeight: Int = 1920

  static var recordingSize: CGSize {
    CGSize(width: currentCameraWidth, height: currentCameraHeight)
  }

  private static func detect() -> DeviceCapabilities {
    let modelIdentifier = getModelIdentifier()
    let modelName = getModelName(from: modelIdentifier)

    if modelIdentifier.contains("iPhone15") || modelIdentifier.contains("iPhone16")
      || modelIdentifier.contains("iPhone17") || modelIdentifier.contains("iPhone14")
      || modelIdentifier.contains("iPhone13")
    {
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

    case "iPhone17,1": return "iPhone 16 Pro"
    case "iPhone17,2": return "iPhone 16 Pro Max"
    case "iPhone17,3": return "iPhone 16"
    case "iPhone17,4": return "iPhone 16 Plus"

    case "iPhone16,1": return "iPhone 15 Pro"
    case "iPhone16,2": return "iPhone 15 Pro Max"
    case "iPhone15,4": return "iPhone 15"
    case "iPhone15,5": return "iPhone 15 Plus"

    case "iPhone15,2": return "iPhone 14 Pro"
    case "iPhone15,3": return "iPhone 14 Pro Max"
    case "iPhone14,7": return "iPhone 14"
    case "iPhone14,8": return "iPhone 14 Plus"

    case "iPhone14,2": return "iPhone 13 Pro"
    case "iPhone14,3": return "iPhone 13 Pro Max"
    case "iPhone14,4": return "iPhone 13 mini"
    case "iPhone14,5": return "iPhone 13"

    case "iPhone13,1": return "iPhone 12 mini"
    case "iPhone13,2": return "iPhone 12"
    case "iPhone13,3": return "iPhone 12 Pro"
    case "iPhone13,4": return "iPhone 12 Pro Max"

    case "x86_64", "arm64": return "Simulator"
    default: return identifier
    }
  }
}

extension DeviceCapabilities {

  static var screenPixelSize: CGSize {
    let screen = UIScreen.main
    let scale = screen.scale
    return CGSize(
      width: screen.bounds.width * scale,
      height: screen.bounds.height * scale
    )
  }
}
