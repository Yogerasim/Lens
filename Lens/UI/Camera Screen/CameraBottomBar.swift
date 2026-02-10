import SwiftUI

struct CameraBottomBar: View {

    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var shaderManager: ShaderManager
    @ObservedObject var mediaRecorder: MediaRecorder
    @State private var isFlashing: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            ShaderIndicatorRow(shaderManager: shaderManager)

            ZoomPresetRow(cameraManager: cameraManager)

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
