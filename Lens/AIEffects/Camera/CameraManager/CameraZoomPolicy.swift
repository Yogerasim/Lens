import CoreGraphics
internal import AVFoundation

enum CameraLensKind: String {
    case ultra
    case wide
    case tele
    case front
    case depth
}

struct CameraZoomHysteresis {
    let wideToUltra: CGFloat = 0.90
    let ultraToWide: CGFloat = 0.98
    let wideToTele: CGFloat = 1.70
    let teleToWide: CGFloat = 1.55
}

struct CameraZoomPolicy {
    let hysteresis = CameraZoomHysteresis()

    func lensKind(
        currentPosition: AVCaptureDevice.Position,
        isDepthEnabled: Bool,
        currentBackDeviceType: AVCaptureDevice.DeviceType
    ) -> CameraLensKind {
        if currentPosition == .front { return .front }
        if isDepthEnabled { return .depth }

        switch currentBackDeviceType {
        case .builtInUltraWideCamera:
            return .ultra
        case .builtInTelephotoCamera:
            return .tele
        default:
            return .wide
        }
    }

    func baseZoom(for deviceType: AVCaptureDevice.DeviceType) -> CGFloat {
        switch deviceType {
        case .builtInUltraWideCamera:
            return 0.5
        case .builtInTelephotoCamera:
            return 2.0
        default:
            return 1.0
        }
    }

    func minimumLogicalZoom(
        capabilities: CameraCapabilities,
        isDepthEnabled: Bool,
        isFront: Bool
    ) -> CGFloat {
        capabilities.minimumLogicalZoom(
            isDepthEnabled: isDepthEnabled,
            isFront: isFront
        )
    }

    func maximumLogicalZoom(
        capabilities: CameraCapabilities,
        isDepthEnabled: Bool,
        isFront: Bool
    ) -> CGFloat {
        capabilities.maximumLogicalZoom(
            isDepthEnabled: isDepthEnabled,
            isFront: isFront
        )
    }

    func desiredLensAfterGesture(
        targetLogicalZoom logical: CGFloat,
        currentLens: CameraLensKind,
        hasUltraWide: Bool,
        hasTelephoto: Bool,
        canSwitchPhysicalLens: Bool
    ) -> CameraLensKind {
        guard canSwitchPhysicalLens else { return currentLens }

        switch currentLens {
        case .ultra:
            if logical > hysteresis.ultraToWide {
                return .wide
            }
            return .ultra

        case .wide:
            if hasUltraWide && logical < hysteresis.wideToUltra {
                return .ultra
            }
            if hasTelephoto && logical > hysteresis.wideToTele {
                return .tele
            }
            return .wide

        case .tele:
            if logical < hysteresis.teleToWide {
                return .wide
            }
            return .tele

        case .front, .depth:
            return currentLens
        }
    }

    func preferredLensForPreset(
        logicalZoom: CGFloat,
        hasUltraWide: Bool,
        hasTelephoto: Bool,
        isDepthEnabled: Bool,
        isFront: Bool
    ) -> CameraLensKind {
        if isDepthEnabled { return .depth }
        if isFront { return .front }

        if logicalZoom <= 0.75, hasUltraWide {
            return .ultra
        }

        if logicalZoom >= 2.0, hasTelephoto {
            return .tele
        }

        return .wide
    }

    func clamp(_ value: CGFloat, min minValue: CGFloat, max maxValue: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, minValue), maxValue)
    }
}
