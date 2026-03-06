import SwiftUI

/// Zoom slider как в стандартной камере iPhone
/// Появляется при свайпе около кнопки записи
struct ZoomSlider: View {
    
    @ObservedObject var cameraManager: CameraManager
    @Binding var isVisible: Bool
    
    var isLiDARMode: Bool
    
    // Диапазон zoom
    private var minZoom: CGFloat {
        if isLiDARMode { return 1.0 }
        return cameraManager.hasUltraWideForUI ? 0.5 : 1.0
    }
    
    private var maxZoom: CGFloat {
        cameraManager.maxDigitalZoomForUI
    }
    
    @State private var dragOffset: CGFloat = 0
    @State private var startZoom: CGFloat = 1.0
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Фон слайдера
                Capsule()
                    .fill(.ultraThinMaterial)
                    .frame(width: geo.size.width, height: 44)
                
                // Маркеры zoom
                HStack(spacing: 0) {
                    ForEach(zoomMarkers, id: \.self) { marker in
                        let position = positionForZoom(marker, in: geo.size.width - 40)
                        
                        VStack(spacing: 2) {
                            Text(zoomLabel(marker))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(isNearZoom(marker) ? .yellow : .white.opacity(0.6))
                        }
                        .position(x: position + 20, y: 22)
                    }
                }
                .frame(width: geo.size.width, height: 44)
                
                // Текущий индикатор
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
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if startZoom == 1.0 && dragOffset == 0 {
                            startZoom = cameraManager.currentZoomFactor
                        }
                        
                        let sliderWidth = geo.size.width - 40
                        let normalizedX = (value.location.x - 20) / sliderWidth
                        let clampedX = max(0, min(1, normalizedX))
                        
                        // Логарифмическая шкала для естественного ощущения
                        let zoom = zoomFromPosition(clampedX)
                        cameraManager.smoothZoom(to: zoom)
                    }
                    .onEnded { _ in
                        startZoom = cameraManager.currentZoomFactor
                        dragOffset = 0
                        
                        // Скрываем слайдер через 2 секунды после отпускания
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                isVisible = false
                            }
                        }
                    }
            )
        }
        .frame(height: 44)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    // MARK: - Helpers
    
    private var zoomMarkers: [CGFloat] {
        if isLiDARMode {
            return [1.0, 2.0, 5.0, 9.0]
        }
        
        var markers: [CGFloat] = []
        if cameraManager.hasUltraWideForUI { markers.append(0.5) }
        markers.append(contentsOf: [1.0, 2.0])
        if cameraManager.hasTelephotoForUI { markers.append(5.0) }
        markers.append(9.0)
        return markers
    }
    
    private func positionForZoom(_ zoom: CGFloat, in width: CGFloat) -> CGFloat {
        // Логарифмическая шкала: 0.5 → 0, 1 → ~0.2, 2 → ~0.4, 9 → 1
        let logMin = log(minZoom)
        let logMax = log(maxZoom)
        let logZoom = log(zoom)
        
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

#Preview {
    ZStack {
        Color.black
        
        VStack {
            Spacer()
            
            ZoomSlider(
                cameraManager: CameraManager(),
                isVisible: .constant(true),
                isLiDARMode: false
            )
            .padding(.horizontal, 40)
            .padding(.bottom, 100)
        }
    }
}
