import SwiftUI

struct CameraTopBar: View {

    @ObservedObject var shaderManager: ShaderManager
    @ObservedObject var mediaRecorder: MediaRecorder
    @ObservedObject var fps: FPSCounter

    var body: some View {
        HStack {
            // LEFT: shader + fps
            VStack(alignment: .leading, spacing: 4) {
                Text(shaderManager.currentDisplayName.uppercased())
                    .font(.caption.bold())

                if mediaRecorder.isRecording {
                    // Во время записи показываем оба FPS
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CAM: \(fps.fps) FPS")
                            .font(.system(.caption2, design: .monospaced))
                        Text("REC: \(fps.recordingFPS) FPS")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(fps.recordingFPS > 0 ? .green : .red)
                    }
                } else {
                    Text("FPS: \(fps.fps)")
                        .font(.system(.body, design: .monospaced))
                }
            }
            .foregroundColor(.white)
            .glassPanel(cornerRadius: 18, padding: 10)

            Spacer()

            // CENTER/RIGHT: recording timer chip
            if mediaRecorder.isRecording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 10, height: 10)

                    Text(formatDuration(mediaRecorder.recordingDuration))
                        .font(.system(.body, design: .monospaced))
                }
                .foregroundColor(.white)
                .glassPanel(cornerRadius: 18, padding: 10)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.red.opacity(0.35), lineWidth: 1)
                )
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
