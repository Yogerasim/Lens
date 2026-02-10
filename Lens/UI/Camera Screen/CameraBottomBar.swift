import SwiftUI

struct CameraBottomBar: View {

    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var shaderManager: ShaderManager
    @ObservedObject var mediaRecorder: MediaRecorder

    var body: some View {
        VStack(spacing: 16) {
            ShaderIndicatorRow(shaderManager: shaderManager)

            ZoomPresetRow(cameraManager: cameraManager)

            CaptureModeSelector(mediaRecorder: mediaRecorder)

            CaptureControls(
                cameraManager: cameraManager,
                mediaRecorder: mediaRecorder
            )
        }
        .padding(.bottom, 20)
    }
}
#Preview {
    CameraOverlay(
        cameraManager: CameraManager(),
        shaderManager: ShaderManager.shared,
        mediaRecorder: MediaRecorder(),
        fps: FPSCounter.shared
    )
    .background(Color.black)
}
