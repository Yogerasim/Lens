import SwiftUI
import CoreMedia

struct ContentView: View {

    @StateObject private var cameraManager = CameraManager()
    @StateObject private var fps = FPSCounter.shared
    @StateObject private var shaderManager = ShaderManager.shared
    @StateObject private var mediaRecorder = MediaRecorder()

    private let renderer = MetalRenderer(layer: CAMetalLayer())

    var body: some View {
        ZStack {
            // Камера с шейдером
            MetalView(renderer: renderer)
                .ignoresSafeArea()
                .gesture(
                    DragGesture(minimumDistance: 50)
                        .onEnded { value in
                            let horizontalAmount = value.translation.width
                            if horizontalAmount < -50 {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    shaderManager.nextShader()
                                }
                            } else if horizontalAmount > 50 {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    shaderManager.previousShader()
                                }
                            }
                        }
                )

            // UI элементы
            VStack {
                // Верхняя панель
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(shaderManager.currentShader.rawValue.uppercased())
                            .font(.caption.bold())
                        Text("FPS: \(fps.fps)")
                            .font(.system(.body, design: .monospaced))
                    }
                    .foregroundColor(.green)
                    .padding(10)
                    .background(.black.opacity(0.6))
                    .cornerRadius(12)
                    
                    Spacer()
                    
                    // Время записи (если записываем)
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
                    
                    // Индикатор шейдеров
                    HStack(spacing: 6) {
                        ForEach(Array(ShaderType.allCases.enumerated()), id: \.element) { index, shader in
                            Circle()
                                .fill(index == shaderManager.currentIndex ? Color.white : Color.white.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .padding(10)
                    .background(.black.opacity(0.6))
                    .cornerRadius(12)
                }
                .padding()
                
                Spacer()
                
                // Подсказка свайпа
                Text("← Свайп для смены фильтра →")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 8)
                
                // Переключатель Фото/Видео
                HStack(spacing: 20) {
                    ForEach(CaptureMode.allCases, id: \.self) { mode in
                        Button(action: {
                            withAnimation {
                                mediaRecorder.captureMode = mode
                            }
                        }) {
                            Text(mode.rawValue)
                                .font(.subheadline.bold())
                                .foregroundColor(mediaRecorder.captureMode == mode ? .yellow : .white.opacity(0.6))
                        }
                    }
                }
                .padding(.bottom, 16)
                
                // Нижняя панель с кнопками
                HStack(alignment: .center, spacing: 0) {
                    // Левая часть - пустая для баланса
                    Spacer()
                        .frame(width: 70)
                    
                    Spacer()
                    
                    // Центральная кнопка - запись/фото
                    Button(action: {
                        handleCaptureButton()
                    }) {
                        ZStack {
                            // Внешний круг
                            Circle()
                                .stroke(Color.white, lineWidth: 4)
                                .frame(width: 70, height: 70)
                            
                            // Внутренний элемент
                            if mediaRecorder.captureMode == .video {
                                // Видео режим
                                if mediaRecorder.isRecording {
                                    // Квадрат стоп
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.red)
                                        .frame(width: 30, height: 30)
                                } else {
                                    // Красный круг для записи
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 54, height: 54)
                                }
                            } else {
                                // Фото режим - белый круг
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 54, height: 54)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Кнопка переключения камеры (справа)
                    Button(action: {
                        cameraManager.switchCamera()
                    }) {
                        Image(systemName: "camera.rotate.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(16)
                            .background(.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .frame(width: 70)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            FramePipeline.shared.renderer = renderer

            // Callback для обработанных кадров с шейдером
            renderer.onRenderedFrame = { renderedBuffer in
                // Сохраняем для фото и записываем видео
                if mediaRecorder.isRecording {
                    let time = CMTime(seconds: CACurrentMediaTime(), preferredTimescale: 600)
                    mediaRecorder.appendVideoFrame(renderedBuffer, at: time)
                } else {
                    // Просто сохраняем последний кадр для фото
                    mediaRecorder.setLastRenderedFrame(renderedBuffer)
                }
            }
            
            cameraManager.onFrame = { pixelBuffer, time in
                FramePipeline.shared.gate.push(
                    pixelBuffer: pixelBuffer,
                    time: time
                )
            }
            
            // Callback для аудио
            cameraManager.onAudioSample = { sampleBuffer in
                if mediaRecorder.isRecording {
                    mediaRecorder.appendAudioSample(sampleBuffer)
                }
            }

            cameraManager.start()
        }
        .onDisappear {
            cameraManager.stop()
            if mediaRecorder.isRecording {
                mediaRecorder.stopRecording()
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Actions
    
    private func handleCaptureButton() {
        if mediaRecorder.captureMode == .video {
            if mediaRecorder.isRecording {
                mediaRecorder.stopRecording()
            } else {
                mediaRecorder.startRecording()
            }
        } else {
            // Фото
            mediaRecorder.takePhoto()
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }
    
    // MARK: - Helpers
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
