import SwiftUI

/// Более стабильный zoom dial:
/// вместо RotationGesture используется DragGesture по окружности,
/// потому что он меньше конфликтует с другими gesture-слоями.
struct ZoomDial: View {
    
    @ObservedObject var cameraManager: CameraManager
    var isLiDARMode: Bool
    
    @State private var isDragging = false
    @State private var gestureStartZoom: CGFloat = 1.0
    @State private var previousAngle: Double?
    
    private let dialSize: CGFloat = 68
    
    private var minZoom: CGFloat {
        if isLiDARMode { return 1.0 }
        return cameraManager.hasUltraWideForUI ? 0.5 : 1.0
    }
    
    private var maxZoom: CGFloat {
        cameraManager.maxDigitalZoomForUI
    }
    
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                
                Circle()
                    .stroke(.white.opacity(0.25), lineWidth: 1)
                
                Text(zoomLabel(cameraManager.currentZoomFactor))
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .contentShape(Circle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let angle = angleRadians(for: value.location, center: center)
                        
                        if !isDragging {
                            isDragging = true
                            gestureStartZoom = cameraManager.currentZoomFactor
                            previousAngle = angle
                            cameraManager.zoomGestureBegan()
                            return
                        }
                        
                        guard let previousAngle else { return }
                        
                        var delta = angle - previousAngle
                        if delta > .pi { delta -= 2 * .pi }
                        if delta < -.pi { delta += 2 * .pi }
                        
                        self.previousAngle = angle
                        
                        let newZoom = applyLogStep(
                            startZoom: cameraManager.currentZoomFactor,
                            deltaRadians: delta
                        )
                        
                        cameraManager.zoomGestureChanged(logicalZoom: newZoom)
                    }
                    .onEnded { _ in
                        let finalZoom = cameraManager.currentZoomFactor
                        cameraManager.zoomGestureEnded(targetLogicalZoom: finalZoom)
                        isDragging = false
                        previousAngle = nil
                        gestureStartZoom = finalZoom
                    }
            )
        }
        .frame(width: dialSize, height: dialSize)
    }
    
    private func angleRadians(for point: CGPoint, center: CGPoint) -> Double {
        let dx = point.x - center.x
        let dy = point.y - center.y
        return atan2(dy, dx)
    }
    
    private func applyLogStep(startZoom: CGFloat, deltaRadians: Double) -> CGFloat {
        let sensitivity = 0.55
        let scale = exp(deltaRadians * sensitivity)
        let zoom = startZoom * scale
        return min(max(zoom, minZoom), maxZoom)
    }
    
    private func zoomLabel(_ z: CGFloat) -> String {
        let rounded = (z * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return "\(Int(rounded))×"
        }
        return "\(rounded)×"
    }
}
