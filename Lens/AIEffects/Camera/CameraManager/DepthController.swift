internal import AVFoundation

final class DepthController {
  func applyDepthPolicy(
    needsDepth: Bool,
    isRecording: Bool,
    currentPosition: AVCaptureDevice.Position,
    reason: String,
    setDepthEnabled: (Bool, String) -> Void
  ) {
    if isRecording {
      DebugLog.warning("CameraManager: Depth policy change blocked during recording")
      return
    }

    let canUseDepth = currentPosition == .back

    if needsDepth && canUseDepth {
      setDepthEnabled(true, reason)
    } else if needsDepth && !canUseDepth {
      DebugLog.error("CameraManager: Filter needs depth but we're on front camera - depth disabled")
      setDepthEnabled(false, "Front camera doesn't support depth")
    } else {
      setDepthEnabled(false, reason)
    }
  }

  func setDepthEnabled(
    _ enabled: Bool,
    currentPosition: AVCaptureDevice.Position,
    isDepthEnabled: Bool,
    backCapabilities: CameraCapabilities,
    sessionQueue: DispatchQueue,
    beginConfiguration: @escaping () -> Void,
    commitConfiguration: @escaping () -> Void,
    applyCameraConfiguration: @escaping (AVCaptureDevice, Bool) -> Void,
    resetZoom: @escaping (CGFloat) -> Void,
    publishDepthState: @escaping (Bool, CGFloat) -> Void
  ) {
    if enabled && currentPosition == .front {
      DebugLog.warning("CameraManager: Depth requested on front camera, ignoring")
      return
    }

    guard enabled != isDepthEnabled else {
      return
    }

    sessionQueue.async {
      beginConfiguration()
      defer { commitConfiguration() }

      if enabled {
        if let lidarDevice = backCapabilities.lidarDevice {
          resetZoom(1.0)
          applyCameraConfiguration(lidarDevice, true)
          publishDepthState(true, 1.0)
        } else if let wideDevice = backCapabilities.wideDevice {
          let hasDepthFormats = wideDevice.formats.contains {
            !$0.supportedDepthDataFormats.isEmpty
          }
          if hasDepthFormats {
            resetZoom(1.0)
            applyCameraConfiguration(wideDevice, true)
            publishDepthState(true, 1.0)
          } else {
            DebugLog.error("CameraManager: No depth support available on this device")
          }
        } else {
          DebugLog.error("CameraManager: No back wide camera available for depth")
        }
      } else {
        if let wideDevice = backCapabilities.wideDevice {
          resetZoom(1.0)
          applyCameraConfiguration(wideDevice, false)
        }

        publishDepthState(false, 1.0)
      }
    }
  }
}
