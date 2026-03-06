import SwiftUI
import UIKit

struct CaptureControls: View {

  @ObservedObject var cameraManager: CameraManager
  @ObservedObject var mediaRecorder: MediaRecorder
  @Binding var isFlashing: Bool

  var onLongPress: (() -> Void)? = nil
  var longPressDuration: Double = 0.5

  var body: some View {
    HStack(spacing: 0) {
      Color.clear.frame(width: 70)

      Spacer()

      Button {
        handleCapture()
      } label: {
        ZStack {
          Circle()
            .stroke(Color.white.opacity(0.95), lineWidth: 4)
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
        .overlay(
          Circle()
            .fill(.white.opacity(0.06))
            .frame(width: 70, height: 70)
            .opacity(0)
        )
      }
      .buttonStyle(.plain)
      .simultaneousGesture(
        LongPressGesture(minimumDuration: longPressDuration)
          .onEnded { _ in
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            onLongPress?()
          }
      )

      Spacer()

      Color.clear.frame(width: 70)
    }
    .padding(.horizontal, 20)
    .padding(.bottom, 40)
  }

  private func handleCapture() {
    if mediaRecorder.captureMode == .video {
      if mediaRecorder.isRecording {
        FramePipeline.shared.stopRecording()
        mediaRecorder.stopRecording()
      } else {
        FramePipeline.shared.startRecording()
        mediaRecorder.startRecording()
      }
    } else {
      withAnimation(.easeOut(duration: 0.1)) {
        isFlashing = true
      }

      mediaRecorder.takePhoto()
      UIImpactFeedbackGenerator(style: .medium).impactOccurred()

      DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
        withAnimation(.easeOut(duration: 0.2)) {
          isFlashing = false
        }
      }
    }
  }
}
