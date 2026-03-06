import CoreGraphics
import Foundation

struct CameraZoomState {
    var isGestureActive: Bool = false
    var lastRequestedLogicalZoom: CGFloat = 1.0
    var lastAppliedLogicalZoom: CGFloat = 1.0
    var lastLensSwitchTime: CFAbsoluteTime = 0
    var minimumLensSwitchInterval: CFAbsoluteTime = 0.25

    mutating func beginGesture(currentLogicalZoom: CGFloat) {
        isGestureActive = true
        lastRequestedLogicalZoom = currentLogicalZoom
    }

    mutating func endGesture(targetLogicalZoom: CGFloat) {
        isGestureActive = false
        lastRequestedLogicalZoom = targetLogicalZoom
    }

    mutating func updateAppliedLogicalZoom(_ logicalZoom: CGFloat) {
        lastAppliedLogicalZoom = logicalZoom
        lastRequestedLogicalZoom = logicalZoom
    }

    func canSwitchLens(now: CFAbsoluteTime) -> Bool {
        now - lastLensSwitchTime >= minimumLensSwitchInterval
    }

    mutating func markLensSwitch(now: CFAbsoluteTime) {
        lastLensSwitchTime = now
    }

    mutating func reset(logicalZoom: CGFloat = 1.0) {
        isGestureActive = false
        lastRequestedLogicalZoom = logicalZoom
        lastAppliedLogicalZoom = logicalZoom
        lastLensSwitchTime = 0
    }
}
