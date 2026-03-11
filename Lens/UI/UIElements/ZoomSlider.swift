import SwiftUI

struct ZoomSlider: View {
    @ObservedObject var cameraManager: CameraManager
    var isLiDARMode: Bool

    private var minZoom: CGFloat {
        if isLiDARMode { return 1.0 }
        return cameraManager.hasUltraWideForUI ? 0.5 : 1.0
    }

    private var maxZoom: CGFloat {
        cameraManager.maxDigitalZoomForUI
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .frame(width: geo.size.width, height: 44)

                HStack(spacing: 0) {
                    ForEach(zoomMarkers, id: \.self) { marker in
                        VStack(spacing: 2) {
                            Text(zoomLabel(marker))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(isNearZoom(marker) ? .yellow : .white.opacity(0.6))
                        }
                        .position(
                            x: positionForZoom(marker, in: geo.size.width - 40) + 20,
                            y: 22
                        )
                    }
                }
                .frame(width: geo.size.width, height: 44)

                Circle()
                    .fill(.yellow)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(zoomLabel(cameraManager.currentZoomFactor))
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.black)
                    )
                    .position(
                        x: positionForZoom(cameraManager.currentZoomFactor, in: geo.size.width - 40) + 20,
                        y: 22
                    )
            }
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let sliderWidth = geo.size.width - 40
                        let normalizedX = (value.location.x - 20) / sliderWidth
                        let clampedX = max(0, min(1, normalizedX))
                        let zoom = zoomFromPosition(clampedX)
                        cameraManager.zoomGestureChanged(logicalZoom: zoom)
                    }
                    .onEnded { value in
                        let sliderWidth = geo.size.width - 40
                        let normalizedX = (value.location.x - 20) / sliderWidth
                        let clampedX = max(0, min(1, normalizedX))
                        let zoom = zoomFromPosition(clampedX)
                        cameraManager.zoomGestureEnded(targetLogicalZoom: zoom)
                    }
            )
        }
        .frame(height: 44)
    }

    private var zoomMarkers: [CGFloat] {
        if isLiDARMode {
            return [1.0, 2.0, 5.0, 9.0]
        }

        var markers: [CGFloat] = []
        if cameraManager.hasUltraWideForUI { markers.append(0.5) }
        markers.append(1.0)
        if cameraManager.hasTelephotoForUI { markers.append(2.0) }
        markers.append(contentsOf: [5.0, 9.0])
        return markers
    }

    private func positionForZoom(_ zoom: CGFloat, in width: CGFloat) -> CGFloat {
        let logMin = log(minZoom)
        let logMax = log(maxZoom)
        let logZoom = log(max(minZoom, min(maxZoom, zoom)))
        let normalized = (logZoom - logMin) / (logMax - logMin)
        return normalized * width
    }

    private func zoomFromPosition(_ normalized: CGFloat) -> CGFloat {
        let logMin = log(minZoom)
        let logMax = log(maxZoom)
        let logZoom = logMin + normalized * (logMax - logMin)
        return exp(logZoom)
    }

    private func isNearZoom(_ marker: CGFloat) -> Bool {
        let current = cameraManager.currentZoomFactor
        let tolerance: CGFloat = marker < 1 ? 0.1 : marker * 0.15
        return abs(current - marker) < tolerance
    }

    private func zoomLabel(_ z: CGFloat) -> String {
        if z < 1 {
            return String(format: "%.1f×", z)
        } else if z == z.rounded() {
            return "\(Int(z))×"
        } else {
            return String(format: "%.1f×", z)
        }
    }
}
