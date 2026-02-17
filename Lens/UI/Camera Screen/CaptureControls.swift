import SwiftUI

struct CaptureControls: View {

    @ObservedObject var cameraManager: CameraManager
    @ObservedObject var mediaRecorder: MediaRecorder
    @Binding var isFlashing: Bool

    var body: some View {
        HStack(spacing: 0) {
            // слева пусто — место под будущую кнопку/галерею если понадобится
            Color.clear.frame(width: 70)

            Spacer()

            Button {
                handleCapture()
            } label: {
                ZStack {
                    // внешний контур
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
                // лёгкий “glass highlight” при нажатии, но без изменения размеров
                .overlay(
                    Circle()
                        .fill(.white.opacity(0.06))
                        .frame(width: 70, height: 70)
                        .opacity(0) // базово невидим
                )
            }
            .buttonStyle(.plain)

            Spacer()

            Color.clear.frame(width: 70)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 40)
    }

    private func handleCapture() {
        if mediaRecorder.captureMode == .video {
            if mediaRecorder.isRecording {
                // ✅ FIX: Останавливаем запись через FramePipeline для стабильности
                FramePipeline.shared.stopRecording()
                mediaRecorder.stopRecording()
            } else {
                // ✅ FIX: Запускаем запись через FramePipeline для стабильности
                FramePipeline.shared.startRecording()
                mediaRecorder.startRecording()
            }
        } else {
            // Анимация затемнения при съёмке фото
            withAnimation(.easeOut(duration: 0.1)) {
                isFlashing = true
            }
            
            mediaRecorder.takePhoto()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            
            // Убираем затемнение через короткое время
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.easeOut(duration: 0.2)) {
                    isFlashing = false
                }
            }
        }
    }
}
