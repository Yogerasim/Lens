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
  @State private var isIntensityHUDVisible: Bool = false
  @State private var hideHUDWorkItem: DispatchWorkItem?

  @State private var isPinchGestureActive: Bool = false

  var body: some View {
    GeometryReader { geometry in
      let upperZoneHeight = geometry.size.height * 0.67
      let lowerZoneHeight = geometry.size.height - upperZoneHeight

      ZStack {
        Color.black.ignoresSafeArea()

        MetalView(renderer: renderer)
          .aspectRatio(9.0 / 16.0, contentMode: .fit)

        VStack(spacing: 0) {
          Color.clear
            .frame(height: upperZoneHeight)
            .contentShape(Rectangle())
            .gesture(upperZoneGestures)

          Color.clear
            .frame(height: lowerZoneHeight)
            .contentShape(Rectangle())
            .gesture(lowerZoomGestures)
        }

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

  private var lowerZoomGestures: some Gesture {
    MagnificationGesture()
      .onChanged { value in
        let normalized = max(0.5, min(4.0, value))

        if !isPinchGestureActive {
          isPinchGestureActive = true
          pinchStartZoom = cameraManager.currentZoomFactor
          cameraManager.zoomGestureBegan()
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

      }
  }

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

  private func handleVerticalIntensityChanged(_ value: DragGesture.Value) {
    if !isIntensityGestureActive {
      isIntensityGestureActive = true
      intensityGestureStartValue = framePipeline.smoothedIntensity
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
    scheduleHideHUD(delay: 0.8)
  }

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
