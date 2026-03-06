internal import AVFoundation
import CoreGraphics

struct CameraCapabilities {

  let position: AVCaptureDevice.Position

  let hasWide: Bool
  let hasUltraWide: Bool
  let hasTelephoto: Bool
  let hasLiDAR: Bool

  let maxLogicalZoom: CGFloat

  let minLogicalZoomNormal: CGFloat

  let minLogicalZoomDepth: CGFloat

  let devices: [AVCaptureDevice]

  static func make(position: AVCaptureDevice.Position) -> CameraCapabilities {
    let desiredTypes: [AVCaptureDevice.DeviceType] = [
      .builtInWideAngleCamera,
      .builtInUltraWideCamera,
      .builtInTelephotoCamera,
      .builtInLiDARDepthCamera,
    ]

    let discovery = AVCaptureDevice.DiscoverySession(
      deviceTypes: desiredTypes,
      mediaType: .video,
      position: position
    )

    let devices = discovery.devices

    let hasWide = devices.contains { $0.deviceType == .builtInWideAngleCamera }
    let hasUltraWide = devices.contains { $0.deviceType == .builtInUltraWideCamera }
    let hasTelephoto = devices.contains { $0.deviceType == .builtInTelephotoCamera }
    let hasLiDAR = devices.contains { $0.deviceType == .builtInLiDARDepthCamera }

    return CameraCapabilities(
      position: position,
      hasWide: hasWide,
      hasUltraWide: hasUltraWide,
      hasTelephoto: hasTelephoto,
      hasLiDAR: hasLiDAR,
      maxLogicalZoom: 9.0,
      minLogicalZoomNormal: hasUltraWide ? 0.5 : 1.0,
      minLogicalZoomDepth: 1.0,
      devices: devices
    )
  }

  func device(for type: AVCaptureDevice.DeviceType) -> AVCaptureDevice? {
    devices.first(where: { $0.deviceType == type })
  }

  var wideDevice: AVCaptureDevice? {
    device(for: .builtInWideAngleCamera)
  }

  var ultraWideDevice: AVCaptureDevice? {
    device(for: .builtInUltraWideCamera)
  }

  var telephotoDevice: AVCaptureDevice? {
    device(for: .builtInTelephotoCamera)
  }

  var lidarDevice: AVCaptureDevice? {
    device(for: .builtInLiDARDepthCamera)
  }

  func availablePresets(isDepthEnabled: Bool, isFront: Bool) -> [ZoomPreset] {
    if isFront || isDepthEnabled {
      return [.wide]
    }

    var result: [ZoomPreset] = []

    if hasUltraWide {
      result.append(.ultraWide)
    }

    if hasWide {
      result.append(.wide)
    }

    if hasTelephoto {
      result.append(.telephoto)
    }

    if result.isEmpty {
      return [.wide]
    }

    return result
  }

  func minimumLogicalZoom(isDepthEnabled: Bool, isFront: Bool) -> CGFloat {
    if isFront { return 1.0 }
    if isDepthEnabled { return minLogicalZoomDepth }
    return minLogicalZoomNormal
  }

  func maximumLogicalZoom(isDepthEnabled: Bool, isFront: Bool) -> CGFloat {
    if isFront { return maxLogicalZoom }
    if isDepthEnabled { return maxLogicalZoom }
    return maxLogicalZoom
  }
}
