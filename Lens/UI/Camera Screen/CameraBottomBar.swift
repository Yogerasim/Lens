import SwiftUI

struct CameraBottomBar: View {
    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var shaderManager: ShaderManager
    @ObservedObject var mediaRecorder: MediaRecorder

    @State private var isFlashing: Bool = false

    private var isLiDARMode: Bool {
        FramePipeline.shared.activeFilter?.needsDepth == true || cameraManager.isDepthEnabled
    }

    var body: some View {
        VStack(spacing: 16) {
            ShaderIndicatorRow(shaderManager: shaderManager)

            ZoomGlassBar(
                cameraManager: cameraManager,
                isDepthMode: isLiDARMode,
                isFrontCamera: cameraManager.isFrontCamera
            )
            .frame(height: 44)

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
