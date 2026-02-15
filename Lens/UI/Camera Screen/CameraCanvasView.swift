import SwiftUI

struct CameraCanvasView: View {

    let renderer: MetalRenderer

    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var shaderManager: ShaderManager
    @ObservedObject var framePipeline = FramePipeline.shared

    @Binding var pinchStartZoom: CGFloat
    
    // MARK: - Intensity Gesture State
    @State private var intensityStartValue: Float = 1.0
    @State private var showIntensityIndicator: Bool = false
    @State private var hideIntensityTimer: Timer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            MetalView(renderer: renderer)
                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                .gesture(cameraGestures)
            
            // Intensity indicator (справа)
            if showIntensityIndicator {
                intensityIndicatorView
                    .transition(.opacity)
            }
        }
    }
    
    // MARK: - Intensity Indicator
    private var intensityIndicatorView: some View {
        HStack {
            Spacer()
            
            VStack(spacing: 4) {
                Text("🎚️")
                    .font(.system(size: 16))
                
                ZStack(alignment: .bottom) {
                    // Background track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 8, height: 120)
                    
                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .bottom,
                            endPoint: .top
                        ))
                        .frame(width: 8, height: CGFloat(framePipeline.effectIntensity) * 120)
                }
                
                Text("\(Int(framePipeline.effectIntensity * 100))%")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.6))
            )
            .padding(.trailing, 16)
        }
    }

    private var cameraGestures: some Gesture {
        // Magnification (pinch to zoom)
        MagnificationGesture()
            .onChanged { value in
                if abs(value - 1.0) < 0.02 {
                    pinchStartZoom = cameraManager.currentZoomFactor
                }
                cameraManager.setZoom(pinchStartZoom * value)
            }
            .onEnded { _ in
                pinchStartZoom = cameraManager.currentZoomFactor
            }
            // Горизонтальный свайп для смены эффектов
            .simultaneously(with:
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        // Проверяем что это горизонтальный свайп
                        let isHorizontal = abs(value.translation.width) > abs(value.translation.height)
                        
                        if isHorizontal {
                            if value.translation.width < -50 {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    shaderManager.nextShader()
                                }
                            } else if value.translation.width > 50 {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    shaderManager.previousShader()
                                }
                            }
                        }
                    }
            )
            // Вертикальный свайп для intensity
            .simultaneously(with:
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        // Проверяем что это вертикальный свайп
                        let isVertical = abs(value.translation.height) > abs(value.translation.width)
                        
                        if isVertical {
                            // При начале жеста запоминаем стартовое значение
                            if abs(value.translation.height) < 30 {
                                intensityStartValue = framePipeline.effectIntensity
                                print("🖐️ Intensity gesture begin start=\(intensityStartValue)")
                            }
                            
                            // Показываем индикатор
                            withAnimation(.easeOut(duration: 0.15)) {
                                showIntensityIndicator = true
                            }
                            hideIntensityTimer?.invalidate()
                            
                            // Вычисляем новое значение
                            // Свайп вверх увеличивает, вниз уменьшает
                            let sensitivity: Float = 0.003
                            let deltaY = Float(value.translation.height)
                            let newIntensity = max(0.0, min(1.0, intensityStartValue - deltaY * sensitivity))
                            
                            framePipeline.setEffectIntensity(newIntensity)
                        }
                    }
                    .onEnded { value in
                        print("🖐️ Intensity end value=\(framePipeline.effectIntensity)")
                        
                        // Скрываем индикатор через 1.5 сек
                        hideIntensityTimer?.invalidate()
                        hideIntensityTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
                            withAnimation(.easeOut(duration: 0.3)) {
                                showIntensityIndicator = false
                            }
                        }
                    }
            )
    }
}
