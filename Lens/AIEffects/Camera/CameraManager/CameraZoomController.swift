internal import AVFoundation
import CoreGraphics
import Foundation

struct CameraZoomControllerContext {
  let currentPosition: AVCaptureDevice.Position
  let isDepthEnabled: Bool
  let isRecording: Bool
  let currentBackDeviceType: AVCaptureDevice.DeviceType
  let currentCapabilities: CameraCapabilities
  let backCapabilities: CameraCapabilities
  let currentDeviceMaxZoomFactor: CGFloat
}

final class CameraZoomController {
  private let policy: CameraZoomPolicy
  private(set) var state: CameraZoomState

  init(
    policy: CameraZoomPolicy = CameraZoomPolicy(),
    state: CameraZoomState = CameraZoomState()
  ) {
    self.policy = policy
    self.state = state
  }

  var maxLogicalZoomForUI: CGFloat {
    state.lastAppliedLogicalZoom
  }

  func reset(logicalZoom: CGFloat = 1.0) {
    state.reset(logicalZoom: logicalZoom)
  }

  func beginGesture(currentLogicalZoom: CGFloat) {
    state.beginGesture(currentLogicalZoom: currentLogicalZoom)
  }

  func endGesture(targetLogicalZoom: CGFloat) {
    state.endGesture(targetLogicalZoom: targetLogicalZoom)
  }

  func currentLensType(
    currentPosition: AVCaptureDevice.Position,
    isDepthEnabled: Bool,
    currentBackDeviceType: AVCaptureDevice.DeviceType
  ) -> CameraLensKind {
    policy.lensKind(
      currentPosition: currentPosition,
      isDepthEnabled: isDepthEnabled,
      currentBackDeviceType: currentBackDeviceType
    )
  }

  func lensBaseZoom(for deviceType: AVCaptureDevice.DeviceType) -> CGFloat {
    policy.baseZoom(for: deviceType)
  }

  func minimumLogicalZoom(
    capabilities: CameraCapabilities,
    isDepthEnabled: Bool,
    isFront: Bool
  ) -> CGFloat {
    policy.minimumLogicalZoom(
      capabilities: capabilities,
      isDepthEnabled: isDepthEnabled,
      isFront: isFront
    )
  }

  func maximumLogicalZoom(
    capabilities: CameraCapabilities,
    isDepthEnabled: Bool,
    isFront: Bool
  ) -> CGFloat {
    policy.maximumLogicalZoom(
      capabilities: capabilities,
      isDepthEnabled: isDepthEnabled,
      isFront: isFront
    )
  }

  func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
    policy.clamp(value, min: minValue, max: maxValue)
  }

  func backDevice(for lens: CameraLensKind, capabilities: CameraCapabilities) -> AVCaptureDevice? {
    switch lens {
    case .ultra:
      return capabilities.ultraWideDevice ?? capabilities.wideDevice
    case .tele:
      return capabilities.telephotoDevice ?? capabilities.wideDevice
    case .wide, .depth, .front:
      return capabilities.wideDevice
    }
  }

  func applyDeviceZoomForCurrentLogicalIfNeeded(
    context: CameraZoomControllerContext,
    device: AVCaptureDevice,
    setDeviceZoom: (CGFloat, AVCaptureDevice) -> Void
  ) {
    let base: CGFloat
    if context.currentPosition == .front || context.isDepthEnabled {
      base = 1.0
    } else {
      base = lensBaseZoom(for: device.deviceType)
    }

    let minLogical = minimumLogicalZoom(
      capabilities: context.currentCapabilities,
      isDepthEnabled: context.isDepthEnabled,
      isFront: context.currentPosition == .front
    )
    let maxLogical = maximumLogicalZoom(
      capabilities: context.currentCapabilities,
      isDepthEnabled: context.isDepthEnabled,
      isFront: context.currentPosition == .front
    )

    let logical = clamp(state.lastAppliedLogicalZoom, min: minLogical, max: maxLogical)
    let desiredDeviceZoom = clamp(
      logical / base, min: 1.0, max: device.activeFormat.videoMaxZoomFactor)
    setDeviceZoom(desiredDeviceZoom, device)
  }

  func applyDigitalZoomOnly(
    requestedLogical logical: CGFloat,
    context: CameraZoomControllerContext,
    publishLogical: Bool,
    setDeviceZoom: (CGFloat, AVCaptureDevice) -> Void
  ) -> CGFloat? {
    guard let device = contextDevice(context: context) else { return nil }

    let minLogical = minimumLogicalZoom(
      capabilities: context.currentCapabilities,
      isDepthEnabled: context.isDepthEnabled,
      isFront: context.currentPosition == .front
    )
    let maxLogical = maximumLogicalZoom(
      capabilities: context.currentCapabilities,
      isDepthEnabled: context.isDepthEnabled,
      isFront: context.currentPosition == .front
    )

    let requestedLogical = clamp(
      logical, min: minLogical, max: max(maxLogical, context.currentCapabilities.maxLogicalZoom))

    let base: CGFloat
    if context.currentPosition == .front || context.isDepthEnabled {
      base = 1.0
    } else {
      base = lensBaseZoom(for: context.currentBackDeviceType)
    }

    let deviceZoom = clamp(
      requestedLogical / base, min: 1.0, max: device.activeFormat.videoMaxZoomFactor)
    setDeviceZoom(deviceZoom, device)

    let publishedLogical = publishLogical ? requestedLogical : (base * deviceZoom)
    state.lastAppliedLogicalZoom = publishedLogical
    state.lastRequestedLogicalZoom = requestedLogical

    return publishedLogical
  }

  func desiredLensForEndedGesture(
    targetLogicalZoom logical: CGFloat,
    context: CameraZoomControllerContext
  ) -> CameraLensKind {
    let canSwitchPhysicalLens =
      context.currentPosition == .back && !context.isDepthEnabled && !context.isRecording

    return policy.desiredLensAfterGesture(
      targetLogicalZoom: logical,
      currentLens: currentLensType(
        currentPosition: context.currentPosition,
        isDepthEnabled: context.isDepthEnabled,
        currentBackDeviceType: context.currentBackDeviceType
      ),
      hasUltraWide: context.backCapabilities.hasUltraWide,
      hasTelephoto: context.backCapabilities.hasTelephoto,
      canSwitchPhysicalLens: canSwitchPhysicalLens
    )
  }

  func preferredLensForPreset(
    logicalZoom: CGFloat,
    context: CameraZoomControllerContext
  ) -> CameraLensKind {
    policy.preferredLensForPreset(
      logicalZoom: logicalZoom,
      hasUltraWide: context.backCapabilities.hasUltraWide,
      hasTelephoto: context.backCapabilities.hasTelephoto,
      isDepthEnabled: context.isDepthEnabled,
      isFront: context.currentPosition == .front
    )
  }

  func canSwitchLens(now: CFAbsoluteTime) -> Bool {
    state.canSwitchLens(now: now)
  }

  func markLensSwitch(now: CFAbsoluteTime) {
    state.markLensSwitch(now: now)
  }

  func updateAppliedLogicalZoom(_ logicalZoom: CGFloat) {
    state.updateAppliedLogicalZoom(logicalZoom)
  }

  private func contextDevice(context: CameraZoomControllerContext) -> AVCaptureDevice? {
    if context.currentPosition == .front {
      return context.currentCapabilities.wideDevice ?? context.currentCapabilities.devices.first
    }

    if context.isDepthEnabled {
      return context.currentCapabilities.lidarDevice
        ?? context.currentCapabilities.wideDevice
        ?? context.currentCapabilities.devices.first
    }

    switch currentLensType(
      currentPosition: context.currentPosition,
      isDepthEnabled: context.isDepthEnabled,
      currentBackDeviceType: context.currentBackDeviceType
    ) {
    case .ultra:
      return context.backCapabilities.ultraWideDevice ?? context.backCapabilities.wideDevice
    case .tele:
      return context.backCapabilities.telephotoDevice ?? context.backCapabilities.wideDevice
    case .wide, .front, .depth:
      return context.backCapabilities.wideDevice ?? context.backCapabilities.devices.first
    }
  }
}
