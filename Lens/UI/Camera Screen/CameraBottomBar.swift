import SwiftUI

struct CameraBottomBar: View {

  @ObservedObject var cameraManager: CameraManager
  @ObservedObject var shaderManager: ShaderManager
  @ObservedObject var mediaRecorder: MediaRecorder
  @State private var isFlashing: Bool = false
  @State private var isZoomSliderVisible: Bool = false

  private var isLiDARMode: Bool {
    FramePipeline.shared.activeFilter?.needsDepth == true || cameraManager.isDepthEnabled
  }

  var body: some View {
    VStack(spacing: 16) {
      ShaderIndicatorRow(shaderManager: shaderManager)

      if isZoomSliderVisible {
        ZoomSlider(
          cameraManager: cameraManager,
          isVisible: $isZoomSliderVisible,
          isLiDARMode: isLiDARMode
        )
        .padding(.horizontal, 20)
        .frame(height: 44)
        .transition(.opacity)
      } else {

        HStack(spacing: 14) {
          ZoomPresetRow(cameraManager: cameraManager)

          Button {
            withAnimation(.easeOut(duration: 0.2)) {
              isZoomSliderVisible = true
            }
          } label: {
            Image(systemName: "slider.horizontal.3")
              .font(.system(size: 14, weight: .semibold))
              .foregroundColor(.white.opacity(0.7))
              .frame(width: 32, height: 32)
          }
          .buttonStyle(.plain)
        }
        .frame(height: 44)
        .transition(.opacity)
      }

      CaptureModeSelector(mediaRecorder: mediaRecorder)

      CaptureControls(
        cameraManager: cameraManager,
        mediaRecorder: mediaRecorder,
        isFlashing: $isFlashing
      )
    }
    .padding(.bottom, 20)
  }
}
#Preview {
  CameraBottomBar(
    cameraManager: CameraManager(),
    shaderManager: ShaderManager.shared,
    mediaRecorder: MediaRecorder()
  )
  .background(Color.black)
}
