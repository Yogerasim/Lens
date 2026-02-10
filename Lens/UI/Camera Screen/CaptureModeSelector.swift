import SwiftUI

struct CaptureModeSelector: View {

    @ObservedObject var mediaRecorder: MediaRecorder

    var body: some View {
        HStack(spacing: 12) {
            ForEach(CaptureMode.allCases, id: \.self) { mode in
                let isSelected = mediaRecorder.captureMode == mode

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        mediaRecorder.captureMode = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(.subheadline.bold())
                        .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                }
                .buttonStyle(.glass)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(isSelected ? Color.white.opacity(0.35) : Color.clear, lineWidth: 1)
                )
                .opacity(isSelected ? 1.0 : 0.95)
            }
        }
    }
}
