import SwiftUI

struct CameraCanvasView: View {

    let renderer: MetalRenderer

    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var shaderManager: ShaderManager
    @ObservedObject var framePipeline = FramePipeline.shared
    @ObservedObject var orientationManager = OrientationManager.shared  // ✅ Добавлен для iPad fix

    @Binding var pinchStartZoom: CGFloat
    
    // MARK: - Intensity Gesture State
    /// Стартовое значение intensity (фиксируется один раз при начале жеста)
    @State private var intensityGestureStartValue: Float = 1.0
    /// Флаг что жест intensity активен
    @State private var isIntensityGestureActive: Bool = false
    /// Видимость HUD
    @State private var isIntensityHUDVisible: Bool = false
    /// Work item для скрытия HUD
    @State private var hideHUDWorkItem: DispatchWorkItem?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            MetalView(renderer: renderer)
                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                .gesture(combinedGestures)
                .onReceive(orientationManager.$currentOrientation) { newOrientation in
                    // Логируем изменения размера drawable при смене ориентации
                    let width = Int(renderer.metalLayer.drawableSize.width)
                    let height = Int(renderer.metalLayer.drawableSize.height)
                    print("📐 CameraCanvasView: Orientation changed, drawable=\(width)x\(height)")
                }
            
            // Glass Intensity HUD (слева)
            HStack {
                GlassIntensityHUD(
                    value: framePipeline.smoothedIntensity,
                    isVisible: isIntensityHUDVisible
                )
                .padding(.leading, 16)
                Spacer()
            }
        }
    }

    // MARK: - Combined Gestures
    private var combinedGestures: some Gesture {
        // 1. Pinch to zoom
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
            // 2. Horizontal swipe для смены эффектов
            .simultaneously(with: horizontalSwipeGesture)
            // 3. Vertical drag для intensity
            .simultaneously(with: verticalIntensityGesture)
    }
    
    // MARK: - Horizontal Swipe (Effect Change)
    private var horizontalSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 50)
            .onEnded { value in
                let isHorizontal = abs(value.translation.width) > abs(value.translation.height) * 1.5
                
                guard isHorizontal else { return }
                
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
    
    // MARK: - Vertical Intensity Gesture
    private var verticalIntensityGesture: some Gesture {
        DragGesture(minimumDistance: 15)
            .onChanged { value in
                let isVertical = abs(value.translation.height) > abs(value.translation.width) * 1.2
                
                guard isVertical else { return }
                
                // ✅ FIX: Фиксируем стартовое значение ОДИН РАЗ при начале жеста
                if !isIntensityGestureActive {
                    isIntensityGestureActive = true
                    intensityGestureStartValue = framePipeline.smoothedIntensity
                    print("🖐️ Intensity gesture BEGIN start=\(String(format: "%.2f", intensityGestureStartValue))")
                }
                
                // Показываем HUD
                showIntensityHUD()
                
                // ✅ FIX: Вычисляем новое значение относительно ФИКСИРОВАННОГО старта
                let sensitivity: Float = 0.004
                let deltaY = Float(value.translation.height)
                // Свайп ВВЕРХ (deltaY < 0) увеличивает
                // Свайп ВНИЗ (deltaY > 0) уменьшает
                let newIntensity = intensityGestureStartValue - deltaY * sensitivity
                
                // Отправляем в FramePipeline (там будет smoothing)
                framePipeline.setTargetIntensity(newIntensity, reason: "gesture")
            }
            .onEnded { _ in
                isIntensityGestureActive = false
                print("🖐️ Intensity gesture END value=\(String(format: "%.2f", framePipeline.smoothedIntensity))")
                
                // Скрываем HUD через 0.8 сек
                scheduleHideHUD(delay: 0.8)
            }
    }
    
    // MARK: - HUD Visibility Control
    
    private func showIntensityHUD() {
        // Отменяем предыдущий hide
        hideHUDWorkItem?.cancel()
        hideHUDWorkItem = nil
        
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            isIntensityHUDVisible = true
        }
    }
    
    private func scheduleHideHUD(delay: TimeInterval) {
        hideHUDWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [self] in
            withAnimation(.easeOut(duration: 0.25)) {
                isIntensityHUDVisible = false
            }
        }
        
        hideHUDWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
}
