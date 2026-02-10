import SwiftUI

struct CaptureControls: View {

    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var mediaRecorder: MediaRecorder

    var body: some View {
        HStack(spacing: 0) {
            // слева пусто — место под будущую кнопку/галерею если понадобится
            Color.clear.frame(width: 70)

            Spacer()

            Button {
                handleCapture()
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 70, height: 70)

                    if mediaRecorder.captureMode == .video {
                        if mediaRecorder.isRecording {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.red)
                                .frame(width: 30, height: 30)
                        } else {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 54, height: 54)
                        }
                    } else {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 54, height: 54)
                    }
                }
            }

            Spacer()

            Color.clear.frame(width: 70)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }

    private func handleCapture() {
        if mediaRecorder.captureMode == .video {
            mediaRecorder.isRecording
            ? mediaRecorder.stopRecording()
            : mediaRecorder.startRecording()
        } else {
            mediaRecorder.takePhoto()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }
}
