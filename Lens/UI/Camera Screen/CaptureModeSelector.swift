import SwiftUI

struct CaptureModeSelector: View {

    @ObservedObject var mediaRecorder: MediaRecorder

    var body: some View {
        HStack(spacing: 20) {
            ForEach(CaptureMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation {
                        mediaRecorder.captureMode = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.subheadline.bold())
                        .foregroundColor(
                            mediaRecorder.captureMode == mode
                            ? .yellow
                            : .white.opacity(0.6)
                        )
                }
            }
        }
    }
}
