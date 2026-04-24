import SwiftUI

struct CameraCanvasView: View {
    let renderer: MetalRenderer

    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var shaderManager: ShaderManager
    @ObservedObject var framePipeline = FramePipeline.shared
    @ObservedObject var orientationManager = OrientationManager.shared

    @Binding var pinchStartZoom: CGFloat

    @State private var intensityGestureStartValue: Float = 1.0
    @State private var isIntensityGestureActive: Bool = false
    @State private var isIntensityHUDVisible: Bool = true  // Always visible

    @State private var isPinchActive: Bool = false
    @State private var lastMagnificationValue: CGFloat = 1.0

    var body: some View {
        GeometryReader { geometry in
            let upperZoneHeight = geometry.size.height * 0.67

            ZStack {
                Color.black.ignoresSafeArea()

                MetalView(renderer: renderer)
                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
                    .highPriorityGesture(pinchZoomGesture)
                    .onReceive(orientationManager.$currentOrientation) { _ in
                    }

                VStack(spacing: 0) {
                    Color.clear
                        .frame(height: upperZoneHeight)
                        .contentShape(Rectangle())
                        .gesture(upperZoneGestures)

                    Spacer()
                }

                HStack {
                    Spacer()
                    
                    GlassIntensityHUD(
                        value: framePipeline.smoothedIntensity,
                        isVisible: isIntensityHUDVisible
                    )
                    .padding(.trailing, 16)
                    .allowsHitTesting(false)
                }
                .allowsHitTesting(false)
            }
        }
    }

    private var pinchZoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let currentValue = CGFloat(value)

                if !isPinchActive {
                    isPinchActive = true
                    pinchStartZoom = cameraManager.currentZoomFactor
                    lastMagnificationValue = currentValue
                    cameraManager.zoomGestureBegan()
                }

                let relativeScale = currentValue / max(lastMagnificationValue, 0.0001)
                let nextLogicalZoom = max(0.01, cameraManager.currentZoomFactor * relativeScale)

                cameraManager.zoomGestureChanged(logicalZoom: nextLogicalZoom)
                lastMagnificationValue = currentValue
            }
            .onEnded { value in
                let finalValue = CGFloat(value)

                if !isPinchActive {
                    let fallbackZoom = max(0.01, pinchStartZoom * finalValue)
                    cameraManager.zoomGestureBegan()
                    cameraManager.zoomGestureEnded(targetLogicalZoom: fallbackZoom)
                    pinchStartZoom = cameraManager.currentZoomFactor
                    lastMagnificationValue = 1.0
                    isPinchActive = false
                    return
                }

                let finalRelativeScale = finalValue / max(lastMagnificationValue, 0.0001)
                let finalLogicalZoom = max(0.01, cameraManager.currentZoomFactor * finalRelativeScale)

                cameraManager.zoomGestureEnded(targetLogicalZoom: finalLogicalZoom)

                pinchStartZoom = cameraManager.currentZoomFactor
                lastMagnificationValue = 1.0
                isPinchActive = false
            }
    }

    private var upperZoneGestures: some Gesture {
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
            .simultaneously(with: verticalIntensityGesture)
    }

    private var verticalIntensityGesture: some Gesture {
        DragGesture(minimumDistance: 15)
            .onChanged { value in
                let isVertical = abs(value.translation.height) > abs(value.translation.width) * 1.2
                guard isVertical else { return }

                if !isIntensityGestureActive {
                    isIntensityGestureActive = true
                    intensityGestureStartValue = framePipeline.smoothedIntensity
                }

                let sensitivity: Float = 0.004
                let deltaY = Float(value.translation.height)
                let newIntensity = intensityGestureStartValue - deltaY * sensitivity

                framePipeline.setTargetIntensity(newIntensity, reason: "gesture")
            }
            .onEnded { _ in
                isIntensityGestureActive = false
            }
    }
}
