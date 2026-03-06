import SwiftUI

struct CameraCanvasView: View {
    
    let renderer: MetalRenderer
    
    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var shaderManager: ShaderManager
    @ObservedObject var framePipeline = FramePipeline.shared
    @ObservedObject var orientationManager = OrientationManager.shared
    
    @Binding var pinchStartZoom: CGFloat
    
    // MARK: - Intensity Gesture State
    @State private var intensityGestureStartValue: Float = 1.0
    @State private var isIntensityGestureActive: Bool = false
    @State private var isIntensityHUDVisible: Bool = false
    @State private var hideHUDWorkItem: DispatchWorkItem?
    
    // MARK: - Zoom Gesture State
    @State private var isPinchGestureActive: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            let upperZoneHeight = geometry.size.height * 0.67
            let lowerZoneHeight = geometry.size.height - upperZoneHeight
            
            ZStack {
                Color.black.ignoresSafeArea()
                
                MetalView(renderer: renderer)
                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
                    .onReceive(orientationManager.$currentOrientation) { _ in
                        let width = Int(renderer.metalLayer.drawableSize.width)
                        let height = Int(renderer.metalLayer.drawableSize.height)
                        print("📐 CameraCanvasView: Orientation changed, drawable=\(width)x\(height)")
                    }
                
                VStack(spacing: 0) {
                    // Верхние 2/3 — только intensity + смена эффектов
                    Color.clear
                        .frame(height: upperZoneHeight)
                        .contentShape(Rectangle())
                        .gesture(upperZoneGestures)
                    
                    // Нижняя 1/3 — только zoom pinch
                    Color.clear
                        .frame(height: lowerZoneHeight)
                        .contentShape(Rectangle())
                        .gesture(lowerZoomGestures)
                }
                
                // Glass Intensity HUD
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
    }
    
    // MARK: - Lower Zoom Zone
    private var lowerZoomGestures: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let normalized = max(0.5, min(4.0, value))
                
                if !isPinchGestureActive {
                    isPinchGestureActive = true
                    pinchStartZoom = cameraManager.currentZoomFactor
                    cameraManager.zoomGestureBegan()
                    print("🤏 Lower zoom zone BEGIN start=\(String(format: "%.2f", pinchStartZoom))x")
                }
                
                let requested = pinchStartZoom * normalized
                cameraManager.zoomGestureChanged(logicalZoom: requested)
            }
            .onEnded { value in
                let normalized = max(0.5, min(4.0, value))
                let finalLogical = pinchStartZoom * normalized
                
                cameraManager.zoomGestureEnded(targetLogicalZoom: finalLogical)
                pinchStartZoom = cameraManager.currentZoomFactor
                isPinchGestureActive = false
                
                print("🤏 Lower zoom zone END target=\(String(format: "%.2f", finalLogical))x")
            }
    }
    
    // MARK: - Upper Zone Gestures
    private var upperZoneGestures: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                let absX = abs(value.translation.width)
                let absY = abs(value.translation.height)
                
                if absY > absX * 1.2 {
                    handleVerticalIntensityChanged(value)
                }
            }
            .onEnded { value in
                let absX = abs(value.translation.width)
                let absY = abs(value.translation.height)
                
                if absX > absY * 1.5 {
                    handleHorizontalEffectSwipeEnded(value)
                } else if absY > absX * 1.2 {
                    handleVerticalIntensityEnded()
                }
            }
    }
    
    // MARK: - Horizontal Effects
    private func handleHorizontalEffectSwipeEnded(_ value: DragGesture.Value) {
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
    
    // MARK: - Vertical Intensity
    private func handleVerticalIntensityChanged(_ value: DragGesture.Value) {
        if !isIntensityGestureActive {
            isIntensityGestureActive = true
            intensityGestureStartValue = framePipeline.smoothedIntensity
            print("🖐️ Intensity gesture BEGIN start=\(String(format: "%.2f", intensityGestureStartValue))")
        }
        
        showIntensityHUD()
        
        let sensitivity: Float = 0.004
        let deltaY = Float(value.translation.height)
        let newIntensity = intensityGestureStartValue - deltaY * sensitivity
        
        framePipeline.setTargetIntensity(newIntensity, reason: "gesture")
    }
    
    private func handleVerticalIntensityEnded() {
        guard isIntensityGestureActive else { return }
        
        isIntensityGestureActive = false
        print("🖐️ Intensity gesture END value=\(String(format: "%.2f", framePipeline.smoothedIntensity))")
        scheduleHideHUD(delay: 0.8)
    }
    
    // MARK: - HUD Visibility Control
    private func showIntensityHUD() {
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
