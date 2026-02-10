import SwiftUI

struct CameraTopBar: View {

    @ObservedObject var shaderManager: ShaderManager
    @ObservedObject var mediaRecorder: MediaRecorder
    @ObservedObject var fps: FPSCounter

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(shaderManager.currentShader.rawValue.uppercased())
                    .font(.caption.bold())

                Text("FPS: \(fps.fps)")
                    .font(.system(.body, design: .monospaced))
            }
            .foregroundColor(.white)
            .padding(10)
            .background(.black.opacity(0.6))
            .cornerRadius(12)

            Spacer()

            if mediaRecorder.isRecording {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)

                    Text(formatDuration(mediaRecorder.recordingDuration))
                        .font(.system(.body, design: .monospaced))
                }
                .foregroundColor(.white)
                .padding(10)
                .background(.red.opacity(0.7))
                .cornerRadius(12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
