import SwiftUI

struct ZoomDial: View {

    @ObservedObject var cameraManager: CameraManager
    var isLiDARMode: Bool

    @State private var startZoom: CGFloat = 1.0
    @State private var lastAngle: Angle = .zero

    private var minZoom: CGFloat {
        if isLiDARMode { return 1.0 }
        return cameraManager.hasUltraWideForUI ? 0.5 : 1.0
    }

    private var maxZoom: CGFloat {
        cameraManager.maxDigitalZoomForUI
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 68, height: 68)

            Circle()
                .stroke(.white.opacity(0.25), lineWidth: 1)
                .frame(width: 68, height: 68)

            Text(zoomLabel(cameraManager.currentZoomFactor))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .gesture(
            RotationGesture()
                .onChanged { angle in
                    if lastAngle == .zero {
                        startZoom = cameraManager.currentZoomFactor
                        lastAngle = angle
                        return
                    }

                    let delta = angle.radians - lastAngle.radians
                    lastAngle = angle

                    let newZoom = applyLogStep(startZoom: cameraManager.currentZoomFactor, deltaRadians: delta)
                    
                    // ✅ FIX: используем только setZoomDuringGesture для стабильных 60 FPS
                    cameraManager.setZoomDuringGesture(newZoom)
                }
                .onEnded { _ in
                    lastAngle = .zero
                    
                    // ✅ Завершение zoom жеста без переключения устройств
                    cameraManager.setZoomDuringGesture(cameraManager.currentZoomFactor)
                }
        )
    }

    private func applyLogStep(startZoom: CGFloat, deltaRadians: Double) -> CGFloat {
        let sensitivity = 0.55
        let scale = exp(deltaRadians * sensitivity)
        let z = startZoom * scale
        return min(max(z, minZoom), maxZoom)
    }

    private func zoomLabel(_ z: CGFloat) -> String {
        let rounded = (z * 10).rounded() / 10
        if rounded == rounded.rounded() { return "\(Int(rounded))×" }
        return "\(rounded)×"
    }
}
